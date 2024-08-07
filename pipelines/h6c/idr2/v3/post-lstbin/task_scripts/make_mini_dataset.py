import numpy as np
import yaml
import re
import glob
import os
import sys
import copy
import argparse
from hera_cal import io, frf, datacontainer

# create an argparser for this_file and out_folder
parser = argparse.ArgumentParser()
parser.add_argument("this_file", help="this particular file, used to index into output files")
parser.add_argument("out_folder", help="output folder")
parser.add_argument("--files_to_average", type=int, default=5, help="number of files to average together")
parser.add_argument("--chans_to_average", type=int, default=4, help="number of channels to average together")
parser.add_argument("--ints_per_output_file", type=int, default=36, help="number of integrations per output file")
args = parser.parse_args()

# create out_folder if it doesn't exist
if not os.path.exists(args.out_folder):
    os.makedirs(args.out_folder)

# get all files, as well as those that match the same baseline group as this_file
all_files = sorted(glob.glob(os.path.join(os.path.dirname(args.this_file), re.sub(r'\b\d+\b', '*', os.path.basename(args.this_file)))))

# make sure this file is in all_files
if args.this_file not in all_files:
    raise ValueError(f'{args.this_file} not in {os.path.join(os.path.dirname(args.this_file), glob_str)}')

# get all files of the same baseline group, which assumes that the first two numerical entires upon a split on '.' in a basename are the LST, e.g. zen.LST.5.41217.000.sum.uvh5
all_same_blg_files = sorted(glob.glob(os.path.join(os.path.dirname(args.this_file), re.sub(r'\b\d+\b', '*', os.path.basename(args.this_file), count=2))))

# Get the file lsts from the filenames, using that same assumption
file_lsts = sorted(set(['.'.join([part for part in os.path.basename(f).split('.') if part.isdigit()][0:2]) for f in all_files]))

# get lists of LSTs that are going to go into the same output file
outfile_lst_groups = [file_lsts[i:i + ints_per_output_file * files_to_average] for i in range(0, len(all_same_blg_files), ints_per_output_file * files_to_average)]

# check if this file's index is not one that requires any action
if all_same_blg_files.index(args.this_file) >= len(outfile_lst_groups):
    print(f'This file is {all_same_blg_files.index(args.this_file)}th in the list of files of the same baseline group, ' +
          f'but there are only {len(outfile_lst_groups)} chunks of files to average together.')
    sys.exit(0)

# break the output LST groups into chunks of files to average together
lst_chunk = outfile_lst_groups[all_same_blg_files.index(this_file)]
print(f'Now averaging togther files from {lst_chunk[0]} to {lst_chunk[-1]}.')
chunks_to_load = [lst_chunk[i:i + files_to_average] for i in range(0, len(lst_chunk), files_to_average)]

# loop over chunks of files, averaging down to a single integration and appending the new HERAData object to out_hd
out_hd = None
for chunk in chunks_to_load:
    # skip chunks that would have fewer than files_to_average files in them
    if len(chunk) < files_to_average:
        continue 
    
    # get all files to load, regardless of baseline group
    files_to_load = [f for f in all_files if any(lst in os.path.basename(f) for lst in chunk)]
    hd = io.HERAData(files_to_load)
    data, flags, nsamples = hd.read()

    # create new datacontainers to hold time- and frequency-averaged data products
    avg_data = datacontainer.DataContainer({})
    avg_flags = datacontainer.DataContainer({})
    avg_nsamples = datacontainer.DataContainer({})
    
    # perform time and frequency averaging
    for bl in data:
        # time average with rephasing
        bl_vec =  data.antpos[bl[0]] - data.antpos[bl[1]]
        (avg_data[bl], 
        avg_flags[bl], 
        avg_nsamples[bl], 
        avg_lsts, 
        extra) = frf.timeavg_waterfall(data[bl], 
                                        hd.Ntimes,
                                        flags=flags[bl],
                                        nsamples=nsamples[bl],
                                        wgt_by_nsample=False,
                                        wgt_by_favg_nsample=False,
                                        extra_arrays={'times': data.times},
                                        lsts=data.lsts, 
                                        freqs=data.freqs,
                                        rephase=True, 
                                        bl_vec=bl_vec, 
                                        verbose=False)
        
        # OR flags during time average
        avg_flags[bl][0, np.any(flags[bl], axis=0)] = True
        
        # frequency average: mean of data, OR of flags, sum of nsamples
        avg_data[bl] = np.mean(avg_data[bl].reshape(avg_data[bl].shape[0], -1, chans_to_average), axis=-1)
        avg_flags[bl] = np.any(avg_flags[bl].reshape(avg_flags[bl].shape[0], -1, chans_to_average), axis=-1)
        avg_nsamples[bl] = np.sum(avg_nsamples[bl].reshape(avg_nsamples[bl].shape[0], -1, chans_to_average), axis=-1)
        avg_freqs = np.mean(data.freqs.reshape(-1, chans_to_average), axis=-1)
    
    # attach relevant quantities to datacontainer
    for dc in (avg_data, avg_flags, avg_nsamples):
        dc.freqs = 
        dc.lsts = avg_lsts
        dc.times = 
    # downselect to first time and a subset of frequencies so that the new HERAData object's shape matches the averaged data
    hd.select(frequencies=[hd.freq_array[:len(avg_freqs)]], times=np.unique(hd.time_array)[0], inplace=True)
    hd.update(data=avg_data, flags=avg_flags, nsamples=avg_nsamples)
    
    # update the time, LST, and frequency arrays in the new HERAData object
    for ap in hd.get_antpairs():
        blt_slice = hd._blt_slices[ap]
        hd.time_array[blt_slice] = extra['avg_times']
        hd.lst_array[blt_slice] = avg_lsts
    hd.freq_array = avg_freqs
    
    # concatenate the new HERAData object to the out_hd
    if out_hd is None:
        out_hd = hd
    else:
        out_hd.fast_concat(hd, axis='blt', inplace=True)

# write out the new HERAData object
outfile = re.sub(r'\b\d+\b', '%',re.sub(r'\b\d+\b', '*', os.path.basename(this_file), count=2), count=1).replace('autos', '%')
outfile = os.path.join(out_folder, outfile.replace('*.*', f'{float(lst_chunk[0]) * 12 / np.pi:.2f}_hours.mini_dataset').replace('.%.', '.'))
print(f'Now writing results to {outfile}.')
out_hd.write_uvh5(outfile, clobber=True)
