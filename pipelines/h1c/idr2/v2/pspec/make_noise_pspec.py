"""
Make pspec of noise sims for a subset of IDR2 data

Nick Kern
nkern@berkeley.edu
July, 2020
"""
import numpy as np
import matplotlib.pyplot as plt
from scipy import stats, interpolate
import hera_sim
import hera_pspec as hp
import hera_cal as hc
from pyuvdata import UVData, UVCal, utils as uvutils
import glob
import os
from astropy import constants
import copy
import functools
import operator
from numpy.linalg import norm
import sys

# load config
cf = hp.utils.load_config(sys.argv[1])
params = dict(  list(cf['io'].items()) 
               + list(cf['data'].items()) 
               + list(cf['analysis'].items()) )
algs = cf['algorithm']
alg = algs['pspec']

# additional parameters
Niter = 10

# iterate over Niters
for i in range(Niter):
    
    # get dset files
    dsets = [sorted(glob.glob(os.path.join(params['data_root'], params['data_template'].format(group=i))))]
    dset_pairs = [(0, 0)]

    if i == 0:
        # configure dataset blpairs from first file in dset1
        uvd = UVData()
        uvd.read(dsets[0], read_data=False)

        # get baseline pairs grouped by redundant type
        (bls1, bls2, blps, x1, x2, red_groups, lens,
        angs) = hp.utils.calc_blpair_reds(uvd, uvd, filter_blpairs=True,
                                       exclude_auto_bls=alg['exclude_auto_bls'],
                                       exclude_cross_bls=alg['exclude_cross_bls'],
                                       exclude_permutations=alg['exclude_permutations'],
                                       bl_len_range=params['bl_len_range'], bl_deg_range=params['bl_deg_range'],
                                       xants=params['xants'], extra_info=True)

    # run pspec
    print("\nrunning pspec iteration {}\n{}".format(i, '-'*40))
    hp.pspecdata.pspec_run(dsets, os.path.join(params['out_dir'], alg['outfname'].format(i)),
                           groupname=alg['groupname'],
                           dset_pairs=dset_pairs,
                           blpairs=blps,
                           spw_ranges=alg['spw_ranges'],
                           pol_pairs=params['pol_pairs'], 
                           input_data_weight=alg['input_data_weight'],
                           norm=alg['norm'], 
                           taper=alg['taper'], 
                           beam=alg['beam'], 
                           cosmo=alg['cosmo'],
                           exclude_auto_bls=alg['exclude_auto_bls'],
                           exclude_cross_bls=alg['exclude_cross_bls'],
                           exclude_permutations=alg['exclude_permutations'],
                           store_cov=False,
                           interleave_times=alg['interleave_times'],
                           rephase_to_dset=alg['rephase_to_dset'], 
                           trim_dset_lsts=alg['trim_dset_lsts'],
                           broadcast_dset_flags=alg['broadcast_dset_flags'], 
                           time_thresh=alg['time_thresh'],
                           Jy2mK=alg['Jy2mK'], 
                           file_type=params['filetype'],
                           store_window=alg['store_window'],
                           verbose=False,
                           tsleep=alg['tsleep'],
                           maxiter=alg['maxiter'])

