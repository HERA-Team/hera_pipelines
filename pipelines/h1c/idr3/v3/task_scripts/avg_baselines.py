#! /usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2022 the HERA Project
# Licensed under the MIT License

import argparse
import numpy as np
from hera_cal import io

# Parse arguments
a = argparse.ArgumentParser(
    description='Script for averaging together absolute values of visibilities over baselines. Keeps polarizations separate.'
)
a.add_argument("infile", type=str, help="path to .uvh5 file to average over the baseline axis")
a.add_argument("outfile", type=str, help="path to output file")
a.add_argument("--ant_str", type=str, default='all', help="Whether to average 'all' baselines, 'auto' only, or 'cross' only. Default 'all'.")
a.add_argument("--clobber", default=False, action='store_true', help="Overwrite outfile if it already exists")
args = a.parse_args()
if args.ant_str.lower() not in ['auto', 'cross', 'all']:
    raise ValueError(f"ant_str={args.ant_str} must be 'auto', 'cross', or 'all'.")

# load data
hd = io.HERAData(args.infile)
data, flags, nsamples = hd.read(ant_str=args.ant_str.lower())

# average data
avg_data = {}
avg_flags = {}
avg_nsamples = {}
for pol in data.pols():
    # get list of not-completely flagged baselines for this pol, if there are non, just use all baselines
    unflagged_bls = sorted([bl for bl in data if (pol in bl) and not np.all(flags[bl])])
    if len(unflagged_bls) == 0:
        unflagged_bls = sorted([bl for bl in data if (pol in bl)])

    # results are keyed by lowest unflagged bl
    key = unflagged_bls[0]
    # avg_flags checks whether the entire pixel in the waterfall is flagged
    avg_flags[key] = np.all([flags[bl] for bl in unflagged_bls], axis=0)
    
    # avg_nsamples is the number of unflagged baselines, unless all data are flagged, and then it's the number baselines
    total_nsamples = np.sum([nsamples[bl] for bl in unflagged_bls], axis=0)
    unflagged_nsamples = np.sum([np.where(flags[bl], 0, nsamples[bl]) for bl in unflagged_bls], axis=0)
    avg_nsamples[key] = np.where(avg_flags[key], total_nsamples, unflagged_nsamples)
    
    # avg_data is the average of unflagge data, unless everything is flagged, and then its the average of everything
    total_data_avg = np.mean([np.abs(data[bl]) for bl in unflagged_bls], axis=0)
    unflagged_data_avg = np.nanmean([np.where(flags[bl], np.nan, np.abs(data[bl])) for bl in unflagged_bls], axis=0)
    avg_data[key] = np.where(avg_flags[key], total_data_avg, unflagged_data_avg)

# write results
hd.select(bls=list(avg_data.keys()))
hd.update(data=avg_data, flags=avg_flags, nsamples=avg_nsamples)
hd.write_uvh5(args.outfile, clobber=args.clobber, fix_autos=True)
