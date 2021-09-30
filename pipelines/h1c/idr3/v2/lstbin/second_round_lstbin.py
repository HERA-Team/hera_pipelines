#!/usr/bin/env python
"""
second_round_lstbin.py
-----------------------------------------
Copyright (c) 2021 The HERA Collaboration

This script is used in H1C IDR3 analysis for lst-binning preprocessed epoch data.

It operates on a single set of files with the same starting LST.
The job_index, the index into files in LST order, is taken from int(sys.argv[2]) - 1
This is intended to be part of an array job (see run_second_round_lstbin.sh).

See second_round_lstbin.yaml for relevant parameter selections.
"""
import sys
import os
import numpy as np
import hera_cal as hc
import hera_pspec as hp
import glob
import copy

#-------------------------------------------------------------------------------
# Parse YAML Configuration File and job_index
#-------------------------------------------------------------------------------
config = sys.argv[1]
job_index = int(sys.argv[2]) - 1
cf = hp.utils.load_config(config)
kwargs = {'vis_units': cf['vis_units'], 'outdir': cf['outdir']}

if cf['verbose']:
    print(f'Now performing lstbin job index {job_index}.')

#-------------------------------------------------------------------------------
# Load information about all epochs to figure out which files to load
#-------------------------------------------------------------------------------
config = sys.argv[1]
# load file JDS and lsts
epoch_files = []
epoch_times = []
epoch_lsts = []
file_to_lst_map = {}
for epoch_glob in cf['epoch_globs'][::-1]:
    data_files = glob.glob(epoch_glob)
    dlst, _, file_lst_arrays, file_time_arrays = hc.io.get_file_times(data_files)
    for df, fla in zip(data_files, file_lst_arrays):
        file_to_lst_map[df] = fla
    
    # sort files, lsts, and JDs by JD
    data_files, file_lst_arrays, file_time_arrays = zip(*sorted(zip(data_files, file_lst_arrays, file_time_arrays), key=lambda x: x[2][0]))
    epoch_files.append(data_files)
    epoch_lsts.append(file_lst_arrays)
    epoch_times.append(file_time_arrays)

# sort epochs by JD
epoch_files, epoch_lsts, epoch_times = zip(*sorted(zip(epoch_files, epoch_lsts, epoch_times), key=lambda x: x[2][0][0]))
    
# pick integer day (first day of last epoch) for converting LSTs back to JDs
kwargs['start_jd'] = int(np.floor(epoch_times[-1][0][0]))

# pick first lst as the branch cuta
kwargs['lst_branch_cut'] = epoch_lsts[0][0][0]

# get baselines and antpos from last file in each epoch, combining appropriately
last_hds = [hc.io.HERAData(efiles[-1]) for efiles in epoch_files]
all_bls = sorted(set([bl for hd in last_hds for bl in hd.bls]))
antpos = last_hds[-1].antpos
for hd in last_hds[-2::-1]:
    for ant in hd.antpos:
        if ant not in antpos:
            antpos[ant] = hd.antpos[ant]

# assign files to groups (i.e. jobs)
groups_to_bin = {}
for files, file_lst_arrays in zip(epoch_files, epoch_lsts):
    for file, fla in zip(files, file_lst_arrays):
        if fla[0] in groups_to_bin:
            groups_to_bin[fla[0]].append(file)
        else:
            groups_to_bin[fla[0]] = [file]

# check that there's no numerical mismatch issues in the LSTs
for start_lst_1 in groups_to_bin:
    for start_lst_2 in groups_to_bin:
        if np.abs(start_lst_1 - start_lst_2) > 0:
            if .5 * np.median(dlst) > np.abs(start_lst_1 - start_lst_2):
                raise ValueError(f"First LST bins {start_lst_1} and {start_lst_2} are closer than .5 dlst. " + \
                                  "This function assumes LST bins must have already been perfectly aligned.")

# pick out files to LST-bin for this job
try:
    files_to_bin = list(groups_to_bin.values())[job_index]
except(IndexError):
    print(f'No file group matching job_index {job_index}. Quitting.')
    sys.exit()

#-------------------------------------------------------------------------------
# Load matching data
#-------------------------------------------------------------------------------
hds = [hc.io.HERAData(file) for file in files_to_bin]

# pick antpos, freqs, x_orientation, and integration_time from last epoch
freq_array = copy.deepcopy(hds[-1].freqs)
kwargs['x_orientation'] = copy.deepcopy(hds[-1].x_orientation)
integration_time = np.median(hds[-1].integration_time)

# pick lsts from fullest file
lst_array = sorted([copy.deepcopy(hd.lsts) for hd in hds], key=len)[-1]

# load all data
all_data, all_flags, all_nsamples = ([None for i in range(len(hds))] for n in range(3))
for i, hd in enumerate(hds):
    if cf['verbose']:
        print(f'Now loading data from {hd.filepaths[0]}')
    all_data[i], all_flags[i], all_nsamples[i] = hd.read()
    # reduce memory footprint
    hds[i] = None
    del hd

#-------------------------------------------------------------------------------
# Perform lstbinning/averaging
#-------------------------------------------------------------------------------
# initialize empty data containers
binned_data = hc.datacontainer.DataContainer({bl: np.zeros((len(lst_array), len(freq_array)), dtype=list(all_data[0].values())[0].dtype) for bl in all_bls})
binned_flags = hc.datacontainer.DataContainer({bl: np.ones((len(lst_array), len(freq_array)), dtype=list(all_flags[0].values())[0].dtype) for bl in all_bls})
binned_nsamples = hc.datacontainer.DataContainer({bl: np.zeros((len(lst_array), len(freq_array)), dtype=list(all_nsamples[0].values())[0].dtype) for bl in all_bls})

# average data
if cf['verbose']:
    print(f'Now averaging data with {cf["weighting"]} weighting...')
for bl in list(all_bls):
    sum_of_wgts = np.zeros_like(binned_data[bl], dtype=float)
    every_epoch_flagged = np.ones_like(binned_flags[bl])
    
    if cf['weighting'] == 'nsamples': # used to fill data in unflagged but nsamples=0 pixels (e.g. inpainted)
        sum_of_wgts2 = copy.deepcopy(sum_of_wgts)
        binned_data2 = np.zeros_like(binned_data[bl])
    
    for data, flags, nsamples in zip(all_data, all_flags, all_nsamples):
        if bl in data:
            # add nsamples, taking into account the possibility that it's a truncated file
            binned_nsamples[bl][0:len(nsamples[bl]), :] += nsamples[bl]
            
            # figure out weights
            if cf['weighting'] == 'equal': # all unflagged data is given equal weight
                wgts = (~flags[bl]).astype(float) 
            elif cf['weighting'] == 'freq_avg_nsamples': # unflagged data weighted by freq-averaged nsamples
                wgts = np.mean(nsamples[bl] * (~flags[bl]), axis=1, keepdims=True)
            elif cf['weighting'] == 'nsamples': # unflagged data weighted by nsamples
                wgts = nsamples[bl] * (~flags[bl])
                wgts2 = np.mean(nsamples[bl] * (~flags[bl]), axis=1, keepdims=True)
                sum_of_wgts2[0:len(data[bl]), :] += wgts2
                binned_data2[0:len(data[bl]), :] += data[bl] * wgts2
            else:
                raise ValueError(f"Weighting '{cf['weighting']}' not in the list of acceptable weightings: ['equal', 'nsamples', 'freq_avg_nsamples']")
            
            # add data to binned data, taking into account the possibility that it's a truncated file
            binned_data[bl][0:len(data[bl]), :] += data[bl] * wgts
            sum_of_wgts[0:len(wgts), :] += wgts
            every_epoch_flagged[0:len(flags[bl]), :] &= flags[bl]

    with np.errstate(divide='ignore',invalid='ignore'):
        # normalize by sum of weights
        binned_data[bl] /= sum_of_wgts
           
        # replace data with 0 weights with data using freq-averaged weighting
        if cf['weighting'] == 'nsamples':
            binned_data[bl][sum_of_wgts == 0] = (binned_data2 / sum_of_wgts2)[sum_of_wgts == 0]
    
    # flag bins with no weight and make sure completely flagged cells are flagged
    binned_flags[bl] = (~np.isfinite(binned_data[bl])) | every_epoch_flagged

#-------------------------------------------------------------------------------
# Create lst-binned file
#-------------------------------------------------------------------------------
# form integration time array
_Nbls = len(set([bl[:2] for bl in binned_data]))
kwargs['integration_time'] = np.ones(len(lst_array) * _Nbls, dtype=np.float64) * integration_time

# construct history
kwargs['history'] = f'This file was produced by second_round_lstbin.py with job_index {job_index}, combining the following files:\n'
kwargs['history'] += '\n'.join(files_to_bin)
kwargs['history'] += '\n\nIt was run with the following settings: \n'
kwargs['history'] += '\n'.join(["{} : {}".format(*_d) for _d in cf.items()])
kwargs['history'] += '\n' + hc.version.history_string()

# write result to disk
outfile = cf['file_ext'].format(time=lst_array[0])
if cf['verbose']:
    print(f'Now saving results to {os.path.join(kwargs["outdir"], outfile)}')
hc.io.write_vis(outfile, binned_data, lst_array, freq_array, antpos, flags=binned_flags,
                nsamples=binned_nsamples, filetype='uvh5', overwrite=True, **kwargs)
