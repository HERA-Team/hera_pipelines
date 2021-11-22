"""
Make noise sims for a subset of IDR2 data
See HERA-Team/H1C_IDR2/notebooks/null_tests/making_noise_sims.ipynb
for details.

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

# helper functions
def unique_lsts(uvd):
    lsts = []
    for l in uvd.lst_array:
        if l not in lsts:
            lsts.append(l)
    return lsts

STOKPOLS = ['PI', 'PU', 'PQ', 'PV']
AUTOVISPOLS = ['XX', 'YY', 'EE', 'NN'] + STOKPOLS

# select beam
beam = hp.PSpecBeamUV("/lustre/aoc/projects/hera/nkern/beams/NF_HERA_IQ_power_beam_healpix128.fits")

# select data files to emulate
dstem = "/lustre/aoc/projects/hera/H1C_IDR2/IDR2_2_pspec/v2/one_group/data"
dfiles = sorted(glob.glob(os.path.join(dstem, "zen.grp1.of1.LST.?.*.HH.OCRSLP2XTK.uvh5")))

# get metadata, select baselines to populate
uvd = UVData()
uvd.read(dfiles[0])
pols = ['pI']
reds, lens, angs = hp.utils.get_reds(uvd, pick_data_ants=True, bl_len_range=(0, 150), bl_deg_range=(0, 180), add_autos=True)
antpos, ants = uvd.get_ENU_antpos()
antpos = dict(zip(ants, antpos))
bls = hp.utils.flatten(reds)
blvecs = {bl: antpos[bl[1]] - antpos[bl[0]] for bl in bls}

# parameters
outdir = "noise_sims"
#filename = "noise.onebl.{:03.0f}.LST.{LST:.5f}.OCRSLP2XTK.uvh5"
#filename = "signal.noise.multibl.OCRSLPXTK.uvh5"
filename = "noise.{:03.0f}.LST.{LST:.5f}.OCRSLP2XTK.uvh5"
Niter = 10
add_fg = False
fgfiles = ["/lustre/aoc/projects/hera/nkern/h1c_idr2_analysis/H1C_IDR2/notebooks/" \
           "null_tests/data/rimez_hera_hex37_gsm.uvh5",
           "/lustre/aoc/projects/hera/nkern/h1c_idr2_analysis/H1C_IDR2/notebooks/" \
           "null_tests/data/rimez_hera_hex37_gleam.uvh5"]

# load fg
if add_fg:
    fgs = []
    for fgfile in fgfiles:
        # get fg
        fg = UVData()
        fg.read(fgfile)
        fg_ap = fg.get_antpairs()
        fg_apos, fg_a = fg.get_ENU_antpos()
        fg_apos = dict(zip(fg_a, fg_apos))
        fg_blvecs = {bl: fg_apos[bl[1]] - fg_apos[bl[0]] for bl in fg_ap}
        # match fg to data bls
        data_to_fg = {}
        _bls = []
        for d_bl in bls:
            # if an autocorr, append and skip
            if d_bl[0] == d_bl[1]:
                _bls.append(d_bl)
                continue
            # look for match in data
            for fg_bl in fg_ap:
                # check bl vector match (possibly conjugated)
                if (norm(fg_blvecs[fg_bl][:2] - blvecs[d_bl][:2]) < 1) \
                   or (norm(fg_blvecs[fg_bl][:2] + blvecs[d_bl][:2]) < 1):
                   _bls.append(d_bl)
                   data_to_fg[d_bl] = fg_bl
        # update bls list
        bls = _bls
        pols = [pol for pol in pols if pol in fg.get_pols()]
        fgs.append(fg)

# iterate over data files
np.random.seed(0)
for i, df in enumerate(dfiles):
    print("\nOpening {}\n{}".format(df, '-'*20))

    # load data
    uvd.read(df, bls=bls, polarizations=pols)
    freqs = uvd.freq_array[0]
    lsts = unique_lsts(uvd)
    bls = uvd.get_antpairs()
    crossbls = [bl for bl in bls if bl[0] != bl[1]]
    autobls = [bl for bl in bls if bl[0] == bl[1]]

    # downselect fg time axis if adding
    if add_fg:
        _fgs = []
        for fg in fgs:
            fg_lsts = unique_lsts(fg)
            tinds = [np.argmin(np.abs(fg_lsts - l)) for l in lsts]
            _fgs.append(fg.select(times=np.unique(fg.time_array)[tinds], inplace=False)) 

    # compute Tsys
    Tsys = hp.utils.uvd_to_Tsys(uvd, beam)

    # iterate over Niter    
    for j in range(Niter):
        uvn = copy.deepcopy(uvd)
       
        # iterate over baselines
        for bl in crossbls:
            # get tsys for this bl
            tinds = uvn.antpair2ind(bl)
            tsys = np.sqrt(Tsys.get_data(bl[0], bl[0], squeeze='none') * Tsys.get_data(bl[1], bl[1], squeeze='none'))
            flags = uvn.get_flags(bl[0], bl[0]) + uvn.get_flags(bl[1], bl[1])
            # compute K->Jy coefficient
            coeff = 1e3 / beam.Jy_to_mK(uvn.freq_array[None, :, :, None])
            coeff = coeff / np.sqrt(uvn.channel_width * uvn.integration_time[tinds, None, None, None] * uvn.nsample_array[tinds])
            coeff[~np.isfinite(coeff)] = 0
            # draw noise
            uvn.data_array[tinds] = hera_sim.noise.white_noise((uvn.Ntimes, 1, uvn.Nfreqs, uvn.Npols)) * coeff * tsys
            # add foregrounds if desired
            if add_fg:
                for fg in _fgs:
                    uvn.data_array[blt_inds, 0, :, pol_ind] += fg.get_data(data_to_fg[bl[:2]] + (bl[2],))

        # write data
        outfile = os.path.join(outdir, filename.format(j, LST=uvn.lst_array.min()))
        print("Writing {}".format(outfile))
        uvn.write_uvh5(outfile, clobber=True)

