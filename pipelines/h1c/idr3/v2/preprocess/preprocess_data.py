#!/usr/bin/env python
"""
preprocess_data.py
-----------------------------------------
Copyright (c) 2019 The HERA Collaboration

This script is used in the IDR2 power spectrum pipeline as a 
pre-processing step after calibration, RFI-flagging and LST binning. 
This additional processing includes RFI-flagging, delay CLEANing,
xtalk subtraction, time-averaging, pseudo-stokes visibility formation, and 
foreground filtering.

See preprocess_params.yaml for relevant parameter selections.
"""
import multiprocess
import numpy as np
import hera_cal as hc
import hera_pspec as hp
import hera_qm as hq
import pyuvdata
from pyuvdata import UVData, UVCal
import pyuvdata.utils as uvutils
import uvtools as uvt
import os, sys, glob, yaml, copy
from datetime import datetime
import json
import shutil
from collections import OrderedDict as odict
import time
import re
import h5py


#-------------------------------------------------------------------------------
# Parse YAML Configuration File
#-------------------------------------------------------------------------------
# Get config and load dictionary
config = sys.argv[1]
cf = hp.utils.load_config(config)

# Consolidate IO, data and analysis parameter dictionaries
params = odict(list(cf['io'].items()) + list(cf['data'].items()) + list(cf['analysis'].items()))
assert len(params) == len(cf['io']) + len(cf['data']) + len(cf['analysis']), ""\
       "Repeated parameters found within the scope of io, data and analysis dicts"
algs = cf['algorithm']

# Extract certain parameters used across the script
verbose = params['verbose']
overwrite = params['overwrite']
pols = params['pols']
data_template = os.path.join(params['data_root'], params['data_template'])
cal_ext = params['cal_ext']

# parse data files and calibration files and order by Julian Date or LST (with specified branch cut)
datafiles = glob.glob(data_template)
assert len(datafiles) > 0
_, _, filelsts, filetimes = hc.io.get_file_times(datafiles, filetype='uvh5')
if params.get('lst_sort', False):
    branch_sorter = lambda x: (x[1] - params.get('lst_branch_cut', 0) + 2 * np.pi) % (2 * np.pi)
    timeorder = np.array(sorted([(i, fl[0]) for i, fl in enumerate(filelsts)], key=branch_sorter), dtype=int)[:, 0]
else:
    timeorder = np.argsort([ft[0] for ft in filetimes])
datafiles = [datafiles[ti] for ti in timeorder]
filetimes = [filetimes[ti] for ti in timeorder]
filelsts = [filelsts[ti] for ti in timeorder]

# trim datafiles based on their un-wrapped, mean LST
if params['lst_range'] not in [None, '', 'None', 'none']:
    lst_range = params['lst_range']
    assert isinstance(lst_range, (list, tuple))
    mean_filelsts = np.unwrap([np.mean(np.unwrap(fl)) for fl in filelsts])
    
    # try selection with and without -2pi shift and take whichever yields more files
    select1 = (mean_filelsts > lst_range[0]) & (mean_filelsts < lst_range[1])
    select2 = (mean_filelsts - 2 * np.pi > lst_range[0]) & (mean_filelsts - 2 * np.pi < lst_range[1])
    if select1.sum() >= select2.sum():
        select = np.where(select1)[0]
    else:
        select = np.where(select2)[0]
    datafiles = [datafiles[si] for si in select]
    filetimes = [filetimes[si] for si in select]
    filelsts = [filelsts[si] for si in select]
    assert len(datafiles) > 0, "no datafiles found within lst_range of {} radians".format(lst_range)

if cal_ext in [None, '', 'None', 'none']:
    inp_cals = [None for df in datafiles]
else:
    # check for full path
    if os.path.exists(cal_ext):
        inp_cals = [cal_ext for df in datafiles]
    # check for wildcards
    elif '?' in cal_ext or '*' in cal_ext:
        inp_cals = sorted(glob.glob(cal_ext))
    # assume its an extension
    else:
        inp_cals = ["{}.{}".format(os.path.splitext(df)[0], cal_ext) for df in datafiles]

# open a datafile and select baselines
if params['bls'] is None:
    uv = UVData()
    uv.read(datafiles[0], read_data=False)
    reds, lens, angs = hp.utils.get_reds(uv, pick_data_ants=False, bl_len_range=params['bl_len_range'],
                                         bl_deg_range=params['bl_deg_range'], xants=params['xants'], add_autos=True)
    bls = hp.utils.flatten(reds)
    if params['filter_bls']:
        uv.read(datafiles[0])
        antpairs = uv.get_antpairs()
        bls = [bl for bl in bls if bl in antpairs]
else:
    bls = params['bls']

#-------------------------------------------------------------------------------
# Open log file and start running
#-------------------------------------------------------------------------------
# Open logfile
logfile = os.path.join(params['out_dir'], params['logfile'])
if os.path.exists(logfile) and params['overwrite'] == False:
    raise IOError("logfile {} exists and overwrite == False, "
                  "quitting pipeline...".format(logfile))
lf = open(logfile, "w")

# Combine error and logfiles if requested
if params['joinlog']:
    ef = lf
else:
    ef = open(os.path.join(params['out_dir'], params['errfile']), "w")

# Message that script is now running
tnow = datetime.utcnow()
hp.utils.log("Starting preprocess pipeline on {}\n{}\n".format(tnow, '-'*60), 
             f=lf, verbose=verbose)
hp.utils.log(json.dumps(cf, indent=1) + '\n', f=lf, verbose=verbose)

# Change to working dir
os.chdir(params['work_dir'])

# out_dir should be cleared before each run: issue a warning if not the case
outdir = os.path.join(params['work_dir'], params['out_dir'])
oldfiles = glob.glob(outdir+'/*')
if len(oldfiles) > 0:
    hp.utils.log("\n{}\nWARNING: out_dir should be cleaned before each new run "
                 "to ensure proper functionality.\nIt seems like some files "
                 "currently exist in {}\n{}\n".format('-'*50, outdir, '-'*50), 
                 f=lf, verbose=verbose)

# Define history append function
def append_history(action, param_dict, data_template, inp_cal=None):
    """
    Create a history string to append to data files

    action : str, name of processing action
    param_dict : dict, parameter 'algorithm' dict
    inp_cal : str, string of input calibration
    """
    # make dictionary string from param_dict
    param_str = '\n' + '\n'.join(["{} : {}".format(*_d) for _d in param_dict.items()])
    inp_cal_ext = None
    cal_hist = None
    if inp_cal is not None:
        if isinstance(inp_cal, (tuple, list)):
            # use zeroth entry if fed as a list
            inp_cal = inp_cal[0]
        inp_cal_ext = os.path.basename(inp_cal)
        uvc = UVCal()
        uvc.read_calfits(inp_cal)
        cal_hist = uvc.history
    tnow = datetime.utcnow()
    hist = "\n\nRan preprocess_data.py {} step at\nUTC {} with \nhera_pspec [{}], "\
           "hera_cal [{}],\nhera_qm [{}] and pyuvdata [{}]\non data_template {}\n"\
           "with {} algorithm parameters\n{}\n\nand calibration {} history:\n{}\n" \
           "".format(action, tnow, hp.version.git_hash[:10],
                                   hc.version.git_hash[:10], 
                                   hq.version.git_hash[:10], 
                                   pyuvdata.__version__, data_template,
                                   action, param_str, inp_cal_ext, cal_hist)
    return hist

# Define file extension add function
def get_file_ext(dfile):
    """get second-to-last .*. slot in filename"""
    if isinstance(dfile, (str, np.str)):
        fext = dfile.split('.')[-2]
        return fext
    else:
        return [get_file_ext(df) for df in dfile]

def add_file_ext(dfiles, file_ext, extend_ext=True, outdir=None):
    """
    Add a file extension to a uvh5 file or list of uvh5 files

    Args:
        dfiles : str or list of str
            Datafiles to add extension to
        file_ext : str
            File extension
        extend_ext : bool
            If True, extend file extension to second-to-last '.X.' slot in dfile
            otherwise append extension to a new '.file_ext.' slot. If the slot
            is already named .HH.', we force append even if extend_ext = True.
            For example, if extend_ext = True and file_ext = 'A', you would
            convert 'zen.X.uvh5' into 'zen.XA.uvh5'. If extend_ext = False you
            would get 'zen.X.A.uvh5'. If however the starting filename
            is 'zen.HH.uvh5' you would get 'zen.HH.A.uvh5' regardless of extend_ext.
        outdir : str
            Output directory to write basename to. None is directory of input files.
    """
    # parse dfiles for str or iterable
    array = True
    if isinstance(dfiles, (str, np.str)):
        array = False
        dfiles = [dfiles]

    # iterate over files
    _dfiles = []
    for df in dfiles:
        if outdir is None:
            _outdir = os.path.dirname(df)
        else:
            _outdir = outdir
        df = os.path.join(_outdir, os.path.basename(df))
        # get second-to-last slot
        ext = get_file_ext(df)
        if ext == 'HH' or not extend_ext:
            df = "{}.{}.{}".format(os.path.splitext(df)[0], file_ext, 'uvh5')
        else:
            df = "{}{}.{}".format(os.path.splitext(df)[0], file_ext, 'uvh5')
        _dfiles.append(df)

    if array:
        return _dfiles
    else:
        return _dfiles[0]

# define file template functions
def get_template(dfiles, force_other=False, jd='{jd:.5f}', lst='{lst:.5f}', pol='{pol}', other='*'):
    """
    Given a list of similar filenames that are '.' delimited in
    their basename, find the glob-parseable template that would yield
    the original data filenames. If we can parse the '.XX.' slot that
    is non-static between dfiles as being attributed to JD, LST or POL
    it can be filled with a pre-defined string format, otherwise fill it as other.

    Args:
        dfiles : list of filepaths
        force_other : bool, use other kwarg to fill all non-static parts of filename
        jd : str, fill with this if non-static part is a JD
        lst : str, fill with this if non-static part is an LST
        pol : str, fill with this if non-static part is a polarization
        other : str, if non-static part is none of above use this. Default='*'.
            If None, don't fill at all and remove from template.

    Returns:
        str : string formatable and glob-parseable template
    """
    # assume dirname is constant, and can be taken from zeroth file
    assert isinstance(dfiles, (tuple, list, np.ndarray))
    dirname = os.path.dirname(dfiles[0])
    # get basenames and split by '.' delimiter
    bnames = [os.path.basename(df).split('.') for df in dfiles]
    Nentries = len(bnames[0])
    # for each entry decide if it is static across dfiles or not
    entries = []
    for i in range(Nentries):
        # get set of this entry across files
        s = set([bn[i] for bn in bnames])
        if len(s) == 1:
            # its static
            entries.append(s.pop())
        else:
            # its not static: try to parse its type
            if not force_other:
                # get first set value
                this_entry = s.pop()
                try:
                    # try to get it into an int
                    this_entry = int(this_entry)

                    # if its small, its probably first decimal
                    # of LST: append for now
                    if this_entry in range(7):
                        entries.append(this_entry)
                        continue
                    # if its not, go to the previous entry
                    last_entry = int(entries[-1])
                    # if its small, its probably first decimal
                    # of LST, so replace both with lst format
                    if last_entry in range(7):
                        # its LST
                        entries.pop(-1)
                        entries.append(lst)
                        continue
                    # lastly, it could be JD
                    elif last_entry > 2450000:
                        # its JD
                        entries.pop(-1)
                        entries.append(jd)
                        continue
                except:
                    # try to match it to polarization
                    if this_entry.lower() in ['xx', 'xy', 'yx', 'yy']:
                        entries.append(pol)
                        continue
            # by now if we haven't continued, just use other
            if other is not None:
                entries.append(other)
    # reconstruct template
    return os.path.join(dirname, '.'.join(entries))

def fill_template(data_template, uvd):
    """Fill data template given HERAData or UVData object"""
    # get metadata
    dtime = uvd.integration_time[0] / (24 * 3600)
    dlst = dtime * 2 * np.pi / 86164.0908
    pol = uvutils.polnum2str(uvd.polarization_array[0])
    # fill entries with metadata
    if '{jd:' in data_template:
        data_template = data_template.format(jd=uvd.time_array[0] - dtime / 2, pol='{pol}')
    elif '{lst:' in data_template:
        data_template = data_template.format(lst=uvd.lst_array[0] - dlst / 2, pol='{pol}')
    if '{pol}' in data_template:
        data_template = data_template.format(pol=pol)
    return data_template

# Assign iterator function (for multi-processing)
if params['multiproc']:
    pool = multiprocess.Pool(params['nproc'], maxtasksperchild=1)
    M = pool.map
else:
    M = map

#-------------------------------------------------------------------------------
# RFI-Flag
#-------------------------------------------------------------------------------
if params['rfi_flag']:

    # Start block
    tnow = datetime.utcnow()
    hp.utils.log("\n{}\nstarting RFI flagging: {}\n".format("-"*60, tnow), 
                 f=lf, verbose=verbose)

    # Setup RFI function
    def run_xrfi(i, datafiles=datafiles, p=cf['algorithm']['rfi_flag'], params=params, inp_cal=inp_cals,
                 bls=bls, pols=pols):
        """
        XRFI run function
        
        i : integer, index of datafiles to run for this task
        datafiles : list, list of data filepaths or objects in memory
        p : dict, XRFI algorithmm parameters
        params : dict, global job parameters
        inp_cal : str or UVCal, input calibration to apply to data on-the-fly
        """
        try:
            # Setup delay filter class as container
            df = datafiles[i]
            F = hc.delay_filter.DelayFilter(input_data=df, filetype='uvh5', input_cal=inp_cals[i])
            F.read(bls=bls, polarizations=pols) # load data

            # update F.hd with F.data (which has been calibrated if input_cal is not None)
            F.hd.update(data=F.data)
            
            # run metrics and flag
            uvmet, uvf = hq.xrfi.xrfi_pipe(F.hd, alg=p['detrend_alg'], Kt=p['Kt'], Kf=p['Kf'],
                                           sig_init=p['sig_init'], sig_adj=p['sig_adj'])

            # update flags for each baseline
            for k in F.flags:
                F.flags[k] += uvf.flag_array[:, :, 0]

            # Write to file: this edits F.hd inplace!
            add_to_history = append_history("XRFI", p, get_template(datafiles, force_other=True), inp_cal=inp_cals[i])
            outname = add_file_ext(df, p['file_ext'], outdir=params['out_dir'])
            hc.io.update_uvdata(F.hd, data=F.data, flags=F.flags, add_to_history=add_to_history)
            F.hd.write_uvh5(outname, clobber=overwrite)

        except:
            hp.utils.log("\njob {} threw exception:".format(i), 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1
        return 0

    # Launch jobs
    failures = hp.utils.job_monitor(run_xrfi, range(len(datafiles)), 
                                    "XRFI", M=M, lf=lf, 
                                    maxiter=params['maxiter'], 
                                    verbose=verbose)

    # Update datafiles and inp_cals
    datafiles = add_file_ext(datafiles, algs['rfi_flag']['file_ext'], outdir=params['out_dir'])
    inp_cals = [None for df in datafiles]

    # Finish block
    tnow = datetime.utcnow()
    hp.utils.log("\nfinished RFI flagging: {}\n{}".format(tnow, "-"*60), 
                 f=lf, verbose=verbose)

#-------------------------------------------------------------------------------
# Foreground Filter, CLEAN or in-paint
#-------------------------------------------------------------------------------
if params['fg_filt']:

    # Start block
    tnow = datetime.utcnow()
    hp.utils.log("\n{}\nstarting foreground filtering: {}\n".format("-"*60, tnow), 
                 f=lf, verbose=verbose)

    # Setup filter function
    def run_fg_filt(i, datafiles=datafiles, p=cf['algorithm']['fg_filt'], params=params, inp_cals=inp_cals,
                    bls=bls, pols=pols):
        """
        FG filter, CLEAN or in-paint run function

        i : integer, index of datafiles to run for this task
        datafiles : list, list of data filepaths or objects in memory
        p : dict, XRFI algorithmm parameters
        params : dict, global job parameters
        inp_cal : str or UVCal, input calibration to apply to data on-the-fly
        """
        try:
            # Setup delay filter class as container
            df = datafiles[i]
            F = hc.delay_filter.DelayFilter(df, filetype='uvh5', input_cal=inp_cals[i])

            # check bls are in the file
            bls = [bl for bl in bls if bl in F.bls]
            assert len(bls) > 0, "no bl match for {}".format(df)

            # read and get keys
            F.read(bls=bls, polarizations=pols)
            autokeys = [k for k in F.data if k[0] == k[1]]
            crosskeys = [k for k in F.data if k[0] != k[1]]

            # configure autotol
            if p['clean_params']['autotol'] in ['None', 'none', '', None]:
                p['clean_params']['autotol'] = p['clean_params']['tol']

            # handle flagging
            if p['flag_lsts'] is not None:
                lst_flags = np.zeros(F.Ntimes, np.bool)
                for lcut in p['flag_lsts']:
                    lst_flags += (F.lsts > lcut[0]) & (F.lsts < lcut[1])
                for key in F.flags:
                    F.flags[key] += lst_flags[:, None]
            if p['flag_chans'] is not None:
                chan_flags = np.zeros(F.Nfreqs, np.bool)
                chans = np.arange(F.Nfreqs)
                for fcut in p['flag_chans']:
                    chan_flags += (chans > fcut[0]) & (chans < fcut[1])
                for key in F.flags:
                    F.flags[key] += chan_flags[None, :]
            if p['freq_avg_min_nsamp'] is not None:
                for key in F.nsamples:
                    freq_flags = np.all(np.isclose(F.nsamples[key], 0), axis=0)
                    navg = np.mean(F.nsamples[key][:, ~freq_flags], axis=1)
                    time_flags = navg < p['freq_avg_min_nsamp']
                    F.flags[key] += time_flags[:, None]
            if p.get('apply_hand_flag_files', False):
                F.apply_flags(df.replace('.uvh5', params['hand_flag_ext']))

            # CLEAN
            if p['axis'] in ['freq', 'time']:
                # single 1D CLEAN: first cross then auto
                cp = p['clean_params']
                F.vis_clean(data=F.data, flags=F.flags, ax=p['axis'], horizon=cp['horizon'], standoff=cp['standoff'],
                            min_dly=cp['min_dly'], window=cp['window'], alpha=cp['alpha'], edgecut_low=cp['edgecut_low'],
                            edgecut_hi=cp['edgecut_hi'], tol=cp['tol'], gain=cp['gain'], maxiter=cp['maxiter'],
                            skip_wgt=cp['skip_wgt'], overwrite=True, verbose=verbose, output_prefix='clean',
                            add_clean_residual=False, zeropad=cp['zeropad'], keys=crosskeys)
                F.vis_clean(data=F.data, flags=F.flags, ax=p['axis'], horizon=cp['horizon'], standoff=cp['standoff'],
                            min_dly=cp['min_dly'], window=cp['window'], alpha=cp['alpha'], edgecut_low=cp['edgecut_low'],
                            edgecut_hi=cp['edgecut_hi'], tol=cp['autotol'], gain=cp['gain'], maxiter=cp['maxiter'],
                            skip_wgt=cp['skip_wgt'], overwrite=True, verbose=verbose, output_prefix='clean',
                            add_clean_residual=False, zeropad=cp['zeropad'], keys=autokeys)

            elif p['axis'] == 'freq-time':
                # two 1D CLEANs
                cp = copy.deepcopy(p['clean_params'])
                # ensure all CLEAN params are len-2
                for attr in cp:
                    if not isinstance(cp[attr], (tuple, list)):
                        cp[attr] = (cp[attr], cp[attr])

                # frequency CLEAN: first cross then auto
                F.vis_clean(data=F.data, flags=F.flags, ax='freq', horizon=cp['horizon'][1], standoff=cp['standoff'][1],
                            min_dly=cp['min_dly'][1], window=cp['window'][1], alpha=cp['alpha'][1], edgecut_low=cp['edgecut_low'][1],
                            edgecut_hi=cp['edgecut_hi'][1], tol=cp['tol'][1], gain=cp['gain'][1], maxiter=cp['maxiter'][1],
                            skip_wgt=cp['skip_wgt'][1], overwrite=True, verbose=verbose, output_prefix='clean',
                            add_clean_residual=False, zeropad=cp['zeropad'][1], keys=crosskeys)
                F.vis_clean(data=F.data, flags=F.flags, ax='freq', horizon=cp['horizon'][1], standoff=cp['standoff'][1],
                            min_dly=cp['min_dly'][1], window=cp['window'][1], alpha=cp['alpha'][1], edgecut_low=cp['edgecut_low'][1],
                            edgecut_hi=cp['edgecut_hi'][1], tol=cp['autotol'][1], gain=cp['gain'][1], maxiter=cp['maxiter'][1],
                            skip_wgt=cp['skip_wgt'][1], overwrite=True, verbose=verbose, output_prefix='clean',
                            add_clean_residual=False, zeropad=cp['zeropad'][1], keys=autokeys)

                # time CLEAN: first cross then auto
                F.vis_clean(data=F.clean_data, flags=F.clean_flags, ax='time', horizon=cp['horizon'][0], standoff=cp['standoff'][0],
                            min_dly=cp['min_dly'][0], window=cp['window'][0], alpha=cp['alpha'][0], edgecut_low=cp['edgecut_low'][0],
                            edgecut_hi=cp['edgecut_hi'][0], tol=cp['tol'][0], gain=cp['gain'][0], maxiter=cp['maxiter'][0],
                            skip_wgt=cp['skip_wgt'][0], overwrite=True, verbose=verbose, output_prefix='clean',
                            add_clean_residual=False, zeropad=cp['zeropad'][0], keys=crosskeys, max_frate=cp['max_frate'][1])
                F.vis_clean(data=F.clean_data, flags=F.clean_flags, ax='time', horizon=cp['horizon'][0], standoff=cp['standoff'][0],
                            min_dly=cp['min_dly'][0], window=cp['window'][0], alpha=cp['alpha'][0], edgecut_low=cp['edgecut_low'][0],
                            edgecut_hi=cp['edgecut_hi'][0], tol=cp['autotol'][0], gain=cp['gain'][0], maxiter=cp['maxiter'][0],
                            skip_wgt=cp['skip_wgt'][0], overwrite=True, verbose=verbose, output_prefix='clean',
                            add_clean_residual=False, zeropad=cp['zeropad'][0], keys=autokeys, max_frate=cp['max_frate'][1])

            else:
                raise ValueError("FG_FILT {} axis not recognized".format(p['axis']))

#            # fill flagged nsamples with band-average nsample
#            ec = slice(p['edgecut_low'], None if p['edgecut_hi'] == 0 else -p['edgecut_hi'])
#            for k in F.nsamples:
#                # get flags
#                f = F.flags[k]
#                fw = (~f).astype(np.float)
#                # get band-averaged nsample
#                avg_nsamp = np.ones_like(fw)
#                avg_nsamp *= np.sum(F.nsamples[k][:, ec] * fw[:, ec], axis=1, keepdims=True) \
#                             / np.sum(fw[:, ec], axis=1, keepdims=True).clip(1e-10, np.inf)
#                F.nsamples[k][f] = avg_nsamp[f]

            # trim model
            if p['trim_model']:
                mdl, n = hc.vis_clean.trim_model(F.clean_model, F.clean_resid, F.dnu,
                                                 noise_thresh=p['noise_thresh'], delay_cut=p['delay_cut'],
                                                 kernel_size=p['kernel_size'], edgecut_low=cp['edgecut_low'],
                                                 edgecut_hi=cp['edgecut_hi'], polyfit_deg=p['polyfit_deg'])
                for k in F.clean_data:
                    F.clean_data[k][F.flags[k]] = mdl[k][F.flags[k]]
                    F.clean_resid[k] = (F.data[k] - mdl[k]) * ~F.flags[k]

            # if maxiter == 0, return inputs
            if np.isclose(p['clean_params']['maxiter'], 0):
                F.clean_data = F.data
                F.clean_flags = F.flags
                F.clean_model = F.data * 0
                F.clean_resid = (F.data - F.clean_model) * ~F.flags

            # update history by-hand due to double appending b/c below edits F.hd inplace
            add_to_history = append_history("fg filt", p, get_template(datafiles, force_other=True),
                                            inp_cal=inp_cals[i])
            F.hd.history += add_to_history
            # Write to file
            if p['resid_ext'] is not None:
                # this edits F.hd inplace!
                outname = add_file_ext(df, p['resid_ext'], outdir=params['out_dir'])
                hc.io.update_uvdata(F.hd, data=F.clean_resid)
                F.hd.write_uvh5(outname, clobber=overwrite)
            if p['inpaint_ext'] is not None:
                # this edits F.hd inplace!
                outname = add_file_ext(df, p['inpaint_ext'], outdir=params['out_dir'])
                hc.io.update_uvdata(F.hd, data=F.clean_data, flags=F.clean_flags)
                F.hd.write_uvh5(outname, clobber=overwrite)

        except:
            hp.utils.log("\njob {} threw exception:".format(i), 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1
        return 0

    # Launch jobs
    failures = hp.utils.job_monitor(run_fg_filt, range(len(datafiles)), 
                                    "FG_FILT", M=M, lf=lf, 
                                    maxiter=params['maxiter'], 
                                    verbose=verbose)

    # Update datafiles and inp_cals
    datafiles = add_file_ext(datafiles, algs['fg_filt']['inpaint_ext'], outdir=params['out_dir'])
    inp_cals = [None for df in datafiles]

    # Finish block
    tnow = datetime.utcnow()
    hp.utils.log("\nfinished foreground filtering: {}\n{}".format(tnow, "-"*60), 
                 f=lf, verbose=verbose)

#-------------------------------------------------------------------------------
# Reflection Calibration
#-------------------------------------------------------------------------------
if params['ref_cal']:
    # Start block
    tnow = datetime.utcnow()
    hp.utils.log("\n{}\nstarting reflection calibration: {}\n".format("-"*60, tnow), 
                 f=lf, verbose=verbose)

    # Setup calibration function
    def run_refcal(i, datafiles=datafiles, p=cf['algorithm']['ref_cal'], params=params, inp_cals=inp_cals,
                   bls=bls, pols=pols):
        try:
            # treat i == -1 as a special index for running the full day average
            full_day_avg = False
            if i == -1:
                full_day_avg = True

            if full_day_avg:
                if not p['time_avg']:
                    raise NotImplementedError('full_day_avg option is only available if time_avg is also True.')
                df = datafiles
                cal_ext = 'day_avg.' + cf['algorithm']['ref_cal']['cal_ext']
            else:
                df = datafiles[i]
                cal_ext =  p['cal_ext']

            autokeys = [bl for bl in bls if bl[0] == bl[1]]
            assert len(autokeys) > 0
            autopols = [pol for pol in pols if pol[0] == pol[1]]

            # load reflection fitter
            R = hc.reflections.ReflectionFitter(df, filetype='uvh5', input_cal=inp_cals[i])
            R.read(bls=autokeys, polarizations=autopols, axis='blt')
            times = R.times

            # configure delay ranges
            dly_ranges = []
            for dlyr in p['dly_ranges']:
                if len(dlyr) < 3:
                    dly_ranges.append(dlyr)
                else:
                    dly_ranges.extend([dlyr[:2]] * dlyr[2])

            # time average
            if p['time_avg']:
                R.timeavg_data(R.data, R.times, R.lsts, 1e10, flags=R.flags, nsamples=R.nsamples, rephase=False, 
                               wgt_by_nsample=p['wgt_by_nsample'], wgt_by_favg_nsample=p['wgt_by_favg_nsample'])
                R.data = R.avg_data
                R.flags = R.avg_flags
                R.nsamples = R.avg_nsamples
                if not p['expand_times']:
                    times = R.avg_times

            if isinstance(p['edgecut_low'], (float, int)):
                p['edgecut_low'] = [p['edgecut_low']]
            if isinstance(p['edgecut_hi'], (float, int)):
                p['edgecut_hi'] = [p['edgecut_hi']]
            assert len(p['edgecut_hi']) == len(p['edgecut_low']), "edgecut_low and edgecut_hi must match in len"

            # if full_day_avg, produce one calibration file for each data file
            if full_day_avg:
                corresponding_data_files = datafiles
                corresponding_inp_cals = inp_cals
                corresponding_times = [R.hd.times[cdf] for cdf in corresponding_data_files]
            else:
                corresponding_data_files = [df]
                corresponding_inp_cals = [inp_cals[i]]
                corresponding_times = [times]

            # iterate over spectral windows
            for spwi, spw in enumerate(zip(p['edgecut_low'], p['edgecut_hi'])):
                # iterate over dly_ranges
                R._clear_ref()
                amp, dly, phs, sig = [], [], [], []
                gains = []
                for dlyi, dly_range in enumerate(dly_ranges):
                    if dlyi == 0:
                        r = R
                        cdata = R.data
                    else:
                        r = R.soft_copy()
                        cdata = copy.deepcopy(R.data)
                        hc.apply_cal.calibrate_in_place(cdata, hc.abscal.merge_gains(gains, merge_shared=False))

                    r._clear_ref()
                    r.model_auto_reflections(cdata, dly_range, clean_flags=R.flags, window=p['window'], alpha=p['alpha'],
                                             edgecut_low=spw[0], edgecut_hi=spw[1], reject_edges=True, verbose=False,
                                             zeropad=p['zeropad'], Nphs=p['Nphs'], fthin=p['fthin'], ref_sig_cut=p['ref_sig_cut'])
                    if p['opt_maxiter'] > 0:
                        output = r.refine_auto_reflections(cdata, p['opt_buffer'], r.ref_amp, r.ref_dly, r.ref_phs,
                                                           ref_flags=r.ref_flags, window=p['window'], alpha=p['alpha'],
                                                           edgecut_low=spw[0], edgecut_hi=spw[1],
                                                           clean_flags=r.flags, maxiter=p['opt_maxiter'],
                                                           method=p['opt_method'], tol=p['opt_tol'], verbose=False)
                        r.ref_amp, r.ref_dly, r.ref_phs, _, _, r.ref_gains = output

                    amp.append(r.ref_amp)
                    dly.append(r.ref_dly)
                    phs.append(r.ref_phs)
                    sig.append(r.ref_significance)
                    gains.append(r.ref_gains)

                # write per-spw calfits files, looping over all files if full_day_avg is True
                for cdf, cic, ct in zip(corresponding_data_files, corresponding_inp_cals, corresponding_times):
                    outname = os.path.join(params['out_dir'], os.path.splitext(os.path.basename(cdf))[0])
                    # if running multiple spws then differentiate them in outname        
                    if len(p['edgecut_low']) > 1:
                        outname = "{}.spw{:d}.{}".format(outname, spwi, cal_ext)
                    else:
                        outname = "{}.{}".format(outname, cal_ext)

                    # replace edgecuts in param dict with this iteration's params for file history
                    ref_params = copy.deepcopy(p)
                    ref_params['edgecut_low'] = p['edgecut_low'][spwi]
                    ref_params['edgecut_hi'] = p['edgecut_hi'][spwi]
                    add_to_history = append_history("reflection calibration", ref_params, get_template(datafiles, force_other=True),
                                                    inp_cal=cic)

                    # overwrite ref_amp, ref_dly, ref_phs with list of dicts for output npz file,
                    # even though a list is an invalid type for these attributes
                    r.ref_amp, r.ref_dly, r.ref_phs, r.ref_significance = amp, dly, phs, sig

                    # merge and write gains
                    r.ref_gains = hc.abscal.merge_gains(gains, merge_shared=False)
                    r.write_auto_reflections(outname, input_calfits=cic, overwrite=overwrite,
                                             time_array=ct, add_to_history=add_to_history, verbose=verbose,
                                             write_npz=True)
                    
            # combine spws if desired, looping over all files if full_day_avg is True
            if p['combine_spws'] and len(p['edgecut_low']) > 1:
                for cdf, cic in zip(corresponding_data_files, corresponding_inp_cals):
                    # get spw files
                    outname = os.path.join(params['out_dir'], os.path.splitext(os.path.basename(cdf))[0])
                    spwfiles = sorted(glob.glob("{}.{}.{}".format(outname, '????', cal_ext)))
                    outname = "{}.{}.{}".format(outname, 'allspws', cal_ext)
                    # iterate over each spwfile: truncate gains within edgecut bounds
                    for ii, sf in enumerate(spwfiles):
                        if ii == 0:
                            uvc = UVCal()
                            uvc.read_calfits(sf)
                            _uvc = uvc
                        else:
                            _uvc = UVCal()
                            _uvc.read_calfits(sf)
                        # set gain outside spw boundaries to one
                        if p['spw_boundaries'] is None or p['spw_boundaries'][ii] is None:
                            s = (np.arange(_uvc.Nfreqs) < p['edgecut_low'][ii]) | (np.arange(_uvc.Nfreqs) > (_uvc.Nfreqs - p['edgecut_hi'][ii]))
                        else:
                            s = np.ones(_uvc.Nfreqs, dtype=np.bool)
                            s[slice(p['spw_boundaries'][ii][0], p['spw_boundaries'][ii][1])] = False
                        _uvc.gain_array[:, :, s] = 1.0
                        if ii != 0:
                            # combine gains
                            uvc.gain_array *= _uvc.gain_array
                            uvc.flag_array += _uvc.flag_array

                    # write to disk
                    uvc.history = append_history('reflection calibration', p, get_template(datafiles, force_other=True), cic)
                    uvc.write_calfits(outname, clobber=overwrite)

        except:
            hp.utils.log("\njob {} threw exception:".format(i), 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1
        return 0

    def _update_inp_cal_with_reflections(full_day_avg=False):
        '''Create a list of input calibrations depending on the current step in refleciton calibration.'''
        if full_day_avg:
            cal_ext = 'day_avg.' + cf['algorithm']['ref_cal']['cal_ext']
        else:
            cal_ext = cf['algorithm']['ref_cal']['cal_ext']        

        # update calibration files: if multiple spws computed, inp_cals will be empty unless combine_spws
        if isinstance(cf['algorithm']['ref_cal']['edgecut_low'], (tuple, list)):
            if cf['algorithm']['ref_cal']['combine_spws']:
                ics = []
                for df in datafiles:
                    cfile = os.path.join(params['out_dir'], os.path.splitext(os.path.basename(df))[0])
                    cfile = "{}.{}.{}".format(cfile, 'allspws', cal_ext)
                    ics.append(cfile)
            else:
                if verbose:
                    print("Multiple ref_cal spectral windows computed but not combine_spws," \
                          "therefore downstream pipeline calibration will be None")
                ics = [None for df in datafiles]
        else:
            ics = []
            for df in datafiles:
                cfile = os.path.join(params['out_dir'], os.path.splitext(os.path.basename(df))[0])
                cfile = "{}.{}.{}".format(cfile, cal_ext)
                ics.append(cfile)
                
        return ics

    # Launch jobs, first a single whole-night solution, then one per file
    if cf['algorithm']['ref_cal'].get('full_day_avg_round', False):
        failures = hp.utils.job_monitor(run_refcal, [-1],  # -1 is a special index for running just full_day_avg mode
                                        "AVG_REFCAL", M=M, lf=lf, 
                                        maxiter=params['maxiter'], 
                                        verbose=verbose)
        inp_cals = _update_inp_cal_with_reflections(full_day_avg=True)

    failures = hp.utils.job_monitor(run_refcal, range(len(datafiles)), 
                                "REFCAL", M=M, lf=lf, 
                                maxiter=params['maxiter'], 
                                verbose=verbose)
    inp_cals = _update_inp_cal_with_reflections(full_day_avg=False)


    # setup reflection smoothcal function
    def run_refsmoothcal(inp_cals, p=cf['algorithm']['ref_cal'], params=params):
        try:
            # load all UVCals
            uvcs = []
            for ic in inp_cals:
                uvc = UVCal()
                uvc.read_calfits(ic)
                uvcs.append(uvc)

            # ensure they are time ordered
            times = [uvc.time_array.min() for uvc in uvcs]
            tsort = np.argsort(times)
            uvcs = [uvcs[t] for t in tsort]

            # get time metadata
            times = np.concatenate([np.unique(uvc.time_array) for uvc in uvcs])
            uvc_tinds = []
            for k, uvc in enumerate(uvcs):
                if k == 0:
                    uvc_tinds.append(np.arange(uvc.Ntimes))
                else:
                    uvc_tinds.append(np.arange(uvc.Ntimes) + uvc_tinds[-1][-1] + 1)

            # iterate over antenna-polarization
            ants, pols = uvcs[0].ant_array, uvcs[0].jones_array
            for i in range(len(ants)):
                for j in range(len(pols)):
                    # get gains and wgts for all times
                    g = np.concatenate([u.gain_array[i, 0, :, :, j].T for u in uvcs], axis=0)
                    w = np.concatenate([(~u.flag_array[i, 0, :, :, j].T).astype(np.float) for u in uvcs], axis=0)
                    # smooth
                    gsmooth = hc.smooth_cal.time_filter(g, w, times, filter_scale=p['time_scale'], nMirrors=p['Nmirror'])
                    # iterate over uvcs and re-populate with smoothed gain
                    for k, uvc in enumerate(uvcs):
                        uvc.gain_array[i, 0, :, :, j] = gsmooth[uvc_tinds[k], :].T

            # iterate over input cals and write each file
            for c, ic in enumerate(inp_cals):
                outname = ic.replace(ic.split('.')[-2], ic.split('.')[-2] + p['smooth_cal_ext'])
                uvcs[c].write_calfits(outname, clobber=overwrite)

        except:
            hp.utils.log("\njob threw exception:", 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1
        return 0
 
    # Launch jobs
    if cf['algorithm']['ref_cal']['smooth_ref'] and None not in inp_cals:
        failures = hp.utils.job_monitor(run_refsmoothcal, [inp_cals], 
                                        "REF_SMOOTHCAL", M=M, lf=lf, 
                                        maxiter=params['maxiter'], 
                                        verbose=verbose)

    # update inp_cals
    sce = cf['algorithm']['ref_cal']['smooth_cal_ext']
    inp_cals = [df.replace(df.split('.')[-2], df.split('.')[-2] + sce) for df in inp_cals]

    # finish block
    tnow = datetime.utcnow()
    hp.utils.log("\nfinished reflection calibration: {}\n{}".format(tnow, "-"*60), 
                 f=lf, verbose=verbose)

#-------------------------------------------------------------------------------
# Xtalk Subtraction
#-------------------------------------------------------------------------------
if params['xtalk_sub']:
    
    # Start block
    tnow = datetime.utcnow()
    hp.utils.log("\n{}\nstarting xtalk subtraction: {}\n".format("-"*60, tnow), 
                 f=lf, verbose=verbose)

    # setup baseline groups
    Nbl_per_task = cf['algorithm']['xtalk_sub']['Nbl_per_task']
    if Nbl_per_task is None:
        blgroups = bls
    else:
        blgroups = [bls[i*Nbl_per_task:(i+1)*Nbl_per_task] for i in range(len(bls)//Nbl_per_task + 1)]
    blgroups = [blg for blg in blgroups if len(blg) > 0]

    # get file times from metadata
    hd = hc.io.HERAData(datafiles)
    filetimes = [hd.times[df] for df in hd.times]
    fileorder = np.argsort([ft[0] for ft in filetimes])
    filetimes = [filetimes[oi] for oi in fileorder]
    del hd

    # get glob-parseable data template
    data_template = os.path.basename(get_template(datafiles, force_other=False, jd='{jd:.5f}',
                                                  lst='{lst:.5f}', pol='*', other='*'))

    # setup xtalk sub function
    def run_xtalk_sub(i, blgroups=blgroups, datafiles=datafiles, p=cf['algorithm']['xtalk_sub'], 
                      data_template=data_template, params=params, inp_cals=inp_cals, pols=pols):
        """
        xtalk sub

        i : integer, index of blgroups to run for this task
        blgroups : list, list of baseline groups to operate on
        p : dict, xtalk sub algorithmm parameters
        params : dict, global job parameters
        inp_cal : str or UVCal, input calibration to apply to data on-the-fly
        """
        try:
            # Setup reflection fitter class as container
            if isinstance(inp_cals, list) and None in inp_cals:
                inp_cals = None
            elif isinstance(inp_cals, list):
                # condense calibrations to unique files, in case repetitions exist
                inp_cals = list(np.unique(inp_cals))

            # setup reflection fitter
            R = hc.reflections.ReflectionFitter(datafiles, filetype='uvh5', input_cal=inp_cals)

            # use history of zeroth data file
            history = R.hd.history

            # read data into HERAData
            R.read(bls=blgroups[i], polarizations=pols, axis='blt')
            R.hd.history = history

            # set max frates
            max_frate = {}
            for k in R.data:
                frate = max([0, np.polyval(p['max_frate_coeffs'], abs(R.blvecs[k[:2]][0]))])
                max_frate[k] = min([frate, p['max_frate']])

            # get all keys that meet frate thresh and are unflagged
            keys = [k for k in R.data.keys() if (max_frate[k] >= p['frate_thresh']) and not np.all(R.flags[k])]
            if len(keys) > 0:
                # SVD-based approach
                if 'svd-' in p['method'].lower():
                    if not isinstance(p['edgecut_low'], (tuple, list)):
                        p['edgecut_low'] = [p['edgecut_low']]
                    if not isinstance(p['edgecut_hi'], (tuple, list)):
                        p['edgecut_hi'] = [p['edgecut_hi']]
                    # iterate over edgecuts if provided a list
                    for ii, (el, eh) in enumerate(zip(p['edgecut_low'], p['edgecut_hi'])):
                        # fft to delay space
                        R.fft_data(data=R.data, flags=R.flags, assign='dfft', window=p['window'], alpha=p['alpha'], keys=keys,
                                   edgecut_low=el, edgecut_hi=eh, overwrite=True, ax='freq')

                        # generate weights for svd, assinging 0 weight to excluded lsts and to flags at the beginning or end
                        svd_wgts = R.svd_weights(R.dfft, R.delays, side='both', horizon=p['horizon'], standoff=p['standoff'], 
                                                 min_dly=p['min_dly'], max_dly=p['max_dly'])
                        for key in svd_wgts:
                            unflagged_ints = np.argwhere(~np.all(R.flags[key], axis=1))[:, 0]
                            if len(unflagged_ints) > 0:
                                svd_wgts[key][:unflagged_ints[0], :] = 0
                                svd_wgts[key][(unflagged_ints[-1] + 1):, :] = 0
                            for xlsts in p.get('excluded_lsts', []):
                                svd_wgts[key][(R.lsts >= xlsts[0]) & (R.lsts <= xlsts[1]), :] = 0

                        # take SVD
                        R.sv_decomp(R.dfft, wgts=svd_wgts, flags=R.flags, overwrite=True, Nkeep=p['Nkeep'], sparse_svd=True)

                        # now decide how to smooth them
                        if p['method'].lower() == 'svd-gp':
                            # GP smooth
                            R.interp_u(R.umodes, R.times, full_times=R.times, uflags=R.uflags, overwrite=True,
                                       gp_frate=max_frate, gp_frate_degrade=p['gp_frate_degrade'], gp_nl=1e-12, 
                                       Nmirror=p['gp_Nmirror'], Ninterp=None, xthin=p['xthin'])
                            if p['project_vmodes']:
                                R.vmodes = R.project_svd_modes(R.dfft * svd_wgts, umodes=R.umode_interp, svals=R.svals)

                        # build model and fft back to frequency space
                        R.build_pc_model(R.umode_interp, R.vmodes, R.svals, Nkeep=p['Nkeep'], overwrite=True)

                        # make sure window and edgecuts are the same as before!
                        R.subtract_model(R.data, overwrite=True, window=p['window'], alpha=p['alpha'],
                                         edgecut_low=el, edgecut_hi=eh)

                        # add to container
                        if ii == 0:
                            pcmodel_fft = copy.deepcopy(R.pcomp_model_fft)
                        else:
                            pcmodel_fft += R.pcomp_model_fft

                    # form residual
                    R.data_pcmodel_resid = R.data - pcmodel_fft
                    R.clear_containers(exclude=['data', 'flags', 'nsamples', 'data_pcmodel_resid'])

                # FR filtering method
                elif p['method'].lower() == 'frfilter':
                    # create FR profiles
                    frates = np.fft.fftshift(np.fft.fftfreq(R.Ntimes, R.dtime)) * 1e3
                    frps = hc.datacontainer.DataContainer({})
                    for k in max_frate:
                        frps[k] = np.asarray(np.abs(frates) < max_frate[k], dtype=np.float)

                    R.filter_data(R.data, frps, flags=R.flags, nsamples=R.nsamples, overwrite=True, axis=0, keys=keys,
                                  verbose=params['verbose'])
                    R.data_pcmodel_resid = R.data - R.filt_data

                # linear FR filtering method
                elif p['method'].lower() == 'linear_filter':
                    R.data_pcmodel_resid = hc.datacontainer.DataContainer({})
                    for k in R.data:
                        mfrate = max_frate[k]
                        w = (~R.flags[k]).astype(np.float)
                        mdl = uvt.dspec.fringe_filter(R.data[k], w, mfrate/1e3, R.dtime, tol=p['tol'], linear=True)[0]
                        R.data_pcmodel_resid[k] = R.data[k] - mdl

                else:
                    raise ValueError("xtalk fitting method '%s' not recognized." % p['method'])

                # update hd with residual
                R.hd.update(R.data_pcmodel_resid)

            # for keys not in data_pcmodel_resid, update with data such
            # that calibration (if passed) is applied to these baselines
            cal_data = {k : R.data[k] for k in R.data.keys() if k not in keys}
            R.hd.update(hc.datacontainer.DataContainer(cal_data))

            # configure output filename
            outfname = fill_template(data_template, R.hd)
            outfname = add_file_ext(outfname, p['file_ext'], outdir=params['out_dir'])
            fext = get_file_ext(outfname)
            outfname = '.'.join(outfname.split('.')[:-2]) + '.xtsub{:03d}.{}.uvh5'.format(i, fext)

            # Write to file
            R.hd.history += append_history("xtalk sub", p, get_template(datafiles, force_other=True), inp_cal=inp_cals)
            R.hd.write_uvh5(outfname, clobber=overwrite)
 
        except:
            hp.utils.log("\njob {} threw exception:".format(i), 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1
        return 0

    # Launch jobs
    failures = hp.utils.job_monitor(run_xtalk_sub, range(len(blgroups)),
                                    "XTALK SUB", M=M, lf=lf, 
                                    maxiter=params['maxiter'], 
                                    verbose=verbose)

    # collect output files
    outfname = os.path.basename(get_template(datafiles, force_other=True, other='*'))
    outfname = add_file_ext(outfname, cf['algorithm']['xtalk_sub']['file_ext'], outdir=params['out_dir'])
    fext = get_file_ext(outfname)
    outfname = '.'.join(outfname.split('.')[:-2]) + '.xtsub*.{}.uvh5'.format(fext)
    datafiles = sorted(glob.glob(outfname))

    # merge all outputs into single files
    def xt_merge(i, datafiles=datafiles, filetimes=filetimes, p=cf['algorithm']['xtalk_sub'], params=params,
                 data_template=data_template):
        """
        merge separate baseline files into full-baseline, time-chunked files

        i : int, task integer
        filetimes : list of JD ndarrays for each output file
        p : dict, 'xtalk_sub' step parameters
        params : dict, global parameters
        """
        try:
            # read select times
            hd = hc.io.HERAData(datafiles)
            history = hd.history
            hd.read(times=filetimes[i], return_data=False)
            hd.history = history

            # get output name
            outfname = fill_template(data_template, hd)
            outfname = add_file_ext(outfname, p['file_ext'], outdir=params['out_dir'])

            # write to file
            hd.write_uvh5(outfname, clobber=overwrite)
 
        except:
            hp.utils.log("\njob {} threw exception:".format(i), 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1
        return 0

    # Launch jobs
    failures = hp.utils.job_monitor(xt_merge, range(len(filetimes)),
                                    "XTALK MERGE", M=map, lf=lf, 
                                    maxiter=params['maxiter'], 
                                    verbose=verbose)

    # clean up intermediate files
    if cf['algorithm']['xtalk_sub']['rm_intermediate_files']:
        for df in datafiles:
            if os.path.exists(df):
                os.remove(df)

    # Update datafiles and inp_cals
    datafiles = sorted(glob.glob(outfname.replace(".xtsub*", "")))
    datafiles = [df for df in datafiles if 'xtsub' not in df]
    inp_cals = [None for df in datafiles]

    # Finish block
    tnow = datetime.utcnow()
    hp.utils.log("\nfinished xtalk subtraction: {}\n{}".format(tnow, "-"*60), 
                 f=lf, verbose=verbose)

#-------------------------------------------------------------------------------
# Time Averaging
#-------------------------------------------------------------------------------
if params['time_avg']:
    
    # Start block
    tnow = datetime.utcnow()
    hp.utils.log("\n{}\nstarting time averaging: {}\n".format("-"*60, tnow), 
                 f=lf, verbose=verbose)
    file_Ntimes = cf['algorithm']['time_avg']['file_Ntimes']

    # setup blgroups for parallelization
    Nbl_per_task = cf['algorithm']['time_avg']['Nbl_per_task']
    if Nbl_per_task is None:
        blgroups = bls
    else:
        blgroups = [bls[i*Nbl_per_task:(i+1)*Nbl_per_task] for i in range(len(bls)//Nbl_per_task + 1)]
    blgroups = [blg for blg in blgroups if len(blg) > 0]

    # get glob-parseable data template
    data_template = os.path.basename(get_template(datafiles, force_other=False, jd='{jd:.5f}',
                                                  lst='{lst:.5f}', pol='*', other='*'))

    # setup time avg function
    def run_time_avg(i, blgroups=blgroups, datafiles=datafiles, p=cf['algorithm']['time_avg'], 
                     params=params, inp_cals=inp_cals, data_template=data_template, pols=pols):
        """
        time avg

        i : integer, index of blgroups to run for this task
        blgroups : list, list of baseline groups to operate on
        p : dict, tavg sub algorithm parameters
        params : dict, global job parameters
        """
        try:
            # Setup frfilter class as container
            if isinstance(inp_cals, list) and None in inp_cals:
                inp_cals = None
            elif isinstance(inp_cals, list):
                # condense calibrations to unique files, in case repetitions exist
                inp_cals = list(np.unique(inp_cals))

            F = hc.frf.FRFilter(datafiles, filetype='uvh5', input_cal=inp_cals)
            # use history of zeroth data file
            # we don't like pyuvdata history lengthening upon read-in
            history = F.hd.history
            F.read(bls=blgroups[i], polarizations=pols, axis='blt')
            F.hd.history = history

            # get keys
            keys = list(F.data.keys())

            # timeaverage with rephasing
            F.timeavg_data(F.data, F.times, F.lsts, p['t_window'], flags=F.flags, nsamples=F.nsamples,
                           wgt_by_nsample=p['wgt_by_nsample'], wgt_by_favg_nsample=p['wgt_by_favg_nsample'],
                           rephase=True, verbose=params['verbose'], keys=keys, overwrite=True)

            # flag integrations with too few average nsamples
            if p['freq_avg_min_nsamp'] is not None:
                for key in F.avg_nsamples:
                    freq_flags = np.all(np.isclose(F.avg_nsamples[key], 0), axis=0)
                    navg = np.mean(F.avg_nsamples[key][:, ~freq_flags], axis=1)
                    time_flags = navg < p['freq_avg_min_nsamp']
                    F.avg_flags[key] += time_flags[:, None]

            # configure output name
            outfname = fill_template(data_template, F.hd)
            outfname = add_file_ext(outfname, p['file_ext'], outdir=params['out_dir'])
            fext = get_file_ext(outfname)
            outfname = '.'.join(outfname.split('.')[:-2]) + '.tavg{:03d}.{}.uvh5'.format(i, fext)

            # Write to file
            add_to_history = append_history("time averaging", p, get_template(datafiles, force_other=True), inp_cal=inp_cals)
            F.write_data(F.avg_data, outfname, flags=F.avg_flags, nsamples=F.avg_nsamples,
                         times=F.avg_times, lsts=F.avg_lsts, add_to_history=add_to_history,
                         overwrite=overwrite, filetype='uvh5')
 
        except:
            hp.utils.log("\njob {} threw exception:".format(i), 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1
        return 0

    # Launch jobs
    failures = hp.utils.job_monitor(run_time_avg, range(len(blgroups)), 
                                    "TAVG", M=M, lf=lf, 
                                    maxiter=params['maxiter'], 
                                    verbose=verbose)

    # collect output files
    outfname = os.path.basename(get_template(datafiles, force_other=True, other='*'))
    outfname = add_file_ext(outfname, cf['algorithm']['time_avg']['file_ext'], outdir=params['out_dir'])
    fext = get_file_ext(outfname)
    outfname = '.'.join(outfname.split('.')[:-2]) + '.tavg*.{}.uvh5'.format(fext)
    datafiles = sorted(glob.glob(outfname))

    # configure output file times
    hd = hc.io.HERAData(datafiles[0])
    times = hd.times
    output_times = np.array_split(times, len(times) // file_Ntimes)
    del hd

    # merge all outputs into single files
    def tavg_merge(i, output_times=output_times, p=cf['algorithm']['time_avg'], params=params,
                   data_template=data_template, datafiles=datafiles):
        """
        merge separate baseline files into full-baseline, time-chunked files

        i : int, task integer
        output_times : list of JD ndarrays for each output file
        p : dict, 'time_avg' step parameters
        params : dict, global parameters
        """
        try:
            # read select times
            hd = hc.io.HERAData(datafiles, filetype='uvh5')
            history = hd.history
            hd.read(times=output_times[i], return_data=False)
            hd.history = history

            # get output name
            outfname = fill_template(data_template, hd)
            outfname = add_file_ext(outfname, p['file_ext'], outdir=params['out_dir'])

            # write to file
            hd.write_uvh5(outfname, clobber=overwrite)

        except:
            hp.utils.log("\njob {} threw exception:".format(i), 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1
        return 0

    # Launch jobs
    failures = hp.utils.job_monitor(tavg_merge, range(len(output_times)),
                                    "TAVG MERGE", M=map, lf=lf, 
                                    maxiter=params['maxiter'], 
                                    verbose=verbose)

    # clean up intermediate files
    if cf['algorithm']['time_avg']['rm_intermediate_files']:
        for df in datafiles:
            if os.path.exists(df):
                os.remove(df)

    # Update datafiles and inp_cals
    datafiles = sorted(glob.glob(outfname.replace(".tavg*", "")))
    datafiles = [df for df in datafiles if 'tavg' not in df]
    inp_cals = [None for df in datafiles]

    # Finish block
    tnow = datetime.utcnow()
    hp.utils.log("\nfinished time averaging: {}\n{}".format(tnow, "-"*60), 
                 f=lf, verbose=verbose)

#-------------------------------------------------------------------------------
# Redundant Averaging
#-------------------------------------------------------------------------------
if params['red_avg']:
    
    # Start block
    tnow = datetime.utcnow()
    hp.utils.log("\n{}\nstarting redundant averaging: {}\n".format("-"*60, tnow), 
                 f=lf, verbose=verbose)

    # setup red avg function
    def run_red_avg(i, datafiles=datafiles, p=cf['algorithm']['red_avg'], 
                     params=params, inp_cals=inp_cals, pols=pols):
        try:
            # setup UVData
            df = datafiles[i]
            uvd = UVData()
            uvd.read(df)
            antpos, ants = uvd.get_ENU_antpos()
            antposd = dict(zip(ants, antpos))
            pols = [uvutils.polnum2str(pol) for pol in uvd.polarization_array]

            # load and apply calibration if supplied
            if inp_cals[i] is not None:
                uvc = UVCal()
                uvc.read_calfits(inp_cals[i])
                uvutils.uvcalibrate(uvd, uvc, inplace=True, prop_flags=True, flag_missing=True)

            # get redundant groups
            reds = hc.redcal.get_pos_reds(antposd, bl_error_tol=p['red_tol'])

            # eliminate baselines not in data
            antpairs = uvd.get_antpairs()
            reds = [[bl for bl in blg if bl in antpairs] for blg in reds]
            reds = [blg for blg in reds if len(blg) > 0]

            # iterate over redundant groups and polarizations
            for pol in pols:
                for blg in reds:
                    # get data and weight arrays for this pol-blgroup
                    d = np.asarray([uvd.get_data(bl + (pol,)) for bl in blg])
                    f = np.asarray([(~uvd.get_flags(bl + (pol,))).astype(np.float) for bl in blg])
                    n = np.asarray([uvd.get_nsamples(bl + (pol,)) for bl in blg])
                    if p['wgt_by_nsample']:
                        w = f * n
                    else:
                        w = f

                    # take the weighted average
                    wsum = np.sum(w, axis=0).clip(1e-10, np.inf)
                    davg = np.sum(d * w, axis=0) / wsum
                    navg = np.sum(n, axis=0)
                    favg = np.isclose(wsum, 0.0)

                    # replace in UVData with first bl of blg
                    blinds = uvd.antpair2ind(blg[0])
                    polind = pols.index(pol)
                    uvd.data_array[blinds, 0, :, polind] = davg
                    uvd.flag_array[blinds, 0, :, polind] = favg
                    uvd.nsample_array[blinds, 0, :, polind] = navg

            # select out averaged bls
            bls = hp.utils.flatten([[blg[0] + (pol,) for pol in pols] for blg in reds])
            uvd.select(bls=bls)

            # Write to file
            add_to_history = append_history("redundant averaging", p, get_template(datafiles, force_other=True), inp_cal=inp_cals[i])
            uvd.history += add_to_history
            outname = add_file_ext(df, p['file_ext'], outdir=params['out_dir'])
            uvd.write_uvh5(outname, clobber=overwrite)

        except:
            hp.utils.log("\njob {} threw exception:".format(i), 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1
        return 0

    # Launch jobs
    failures = hp.utils.job_monitor(run_red_avg, range(len(datafiles)), 
                                    "RED_AVG", M=M, lf=lf, 
                                    maxiter=params['maxiter'], 
                                    verbose=verbose)

    # Update datafiles and inp_cals
    datafiles = add_file_ext(datafiles, algs['red_avg']['file_ext'], outdir=params['out_dir'])
    inp_cals = [None for df in datafiles]

    # update bls list
    hd = hc.io.HERAData(datafiles[0])
    bls = sorted(set([bl[:2] for bl in hd.bls]))
    del hd

    # Finish block
    tnow = datetime.utcnow()
    hp.utils.log("\nfinished redundant averaging: {}\n{}".format(tnow, "-"*60), 
                 f=lf, verbose=verbose)

#-------------------------------------------------------------------------------
# Form Pseudo-Stokes Visibilities
#-------------------------------------------------------------------------------
if params['form_pstokes']:

    # Start block
    tnow = datetime.utcnow()
    hp.utils.log("\n{}\nstarting pseudo-stokes: {}\n".format("-"*60, tnow), f=lf, verbose=verbose)

    # Write pseudo-Stokes function
    def make_pstokes(i, datafiles=datafiles, p=cf['algorithm']['pstokes'], params=params, bls=bls, pols=pols,
                     inp_cals=inp_cals):
        """
        Form pseudo-Stokes from uvh5 input.
        Assumes all necessary dipole polarizations are stored in each input file.
        """
        try:
            # Get datafile
            df = datafiles[i]
            
            # Load data
            uvd = UVData()
            uvd.read(df, bls=bls, polarizations=pols)

            # load and apply calibration if supplied
            if inp_cals[i] is not None:
                uvc = UVCal()
                uvc.read_calfits(inp_cals[i])
                uvutils.uvcalibrate(uvd, uvc, inplace=True, prop_flags=True, flag_missing=True)

            # form pseudo stokes
            ps = None
            for i, pstokes in enumerate(p['outstokes']):
                try:
                    if i == 0:
                        ps = hp.pstokes.construct_pstokes(uvd, uvd, pstokes=pstokes)
                    else:
                        ps += hp.pstokes.construct_pstokes(uvd, uvd, pstokes=pstokes)
                except AssertionError:
                    hp.utils.log("failed to make pstokes {} for job {}:".format(pstokes, i), 
                                f=ef, tb=sys.exc_info(), verbose=verbose)

            assert ps is not None, "Couldn't make pstokes {}".format(p['outstokes'])

            # replace history string
            ps.history = uvd.history

            # get output name
            outname = add_file_ext(df, p['file_ext'], outdir=params['out_dir'])

            # attach history
            ps.history = "{}{}".format(ps.history, append_history("FORM PSTOKES", p, get_template(datafiles, force_other=True),
                                                                  inp_cal=inp_cals[i]))
            ps.write_uvh5(outname, clobber=overwrite)

            # Plot waterfalls if requested
            if params['plot']:
                hp.plot.plot_uvdata_waterfalls(ps, 
                                                outfile + ".{pol}.{bl}", 
                                                data='data', 
                                                plot_mode='log', 
                                                format='png')
            
        except:
            hp.utils.log("job {} threw exception:".format(i), 
                         f=ef, tb=sys.exc_info(), verbose=verbose)
            return 1

        return 0

    # Launch jobs
    failures = hp.utils.job_monitor(make_pstokes, 
                                    range(len(datafiles)), 
                                    "PSTOKES", 
                                    M=M, lf=lf, maxiter=params['maxiter'], 
                                    verbose=verbose)

    # Update datafiles and inp_cals
    datafiles = add_file_ext(datafiles, algs['pstokes']['file_ext'], outdir=params['out_dir'])
    inp_cals = [None for df in datafiles]

    # finish block
    tnow = datetime.utcnow()
    hp.utils.log("\nFinished pseudo-stokes: {}\n{}".format(tnow, "-"*60), 
                 f=lf, verbose=verbose)

# close pool
if params['multiproc']:
    pool.close()
