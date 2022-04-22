#! /usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2022 the HERA Project
# Licensed under the MIT License

import argparse
import numpy as np
from hera_cal import io

# Parse arguments
a = argparse.ArgumentParser(
    description='Script to replace aucorrelations in a given file with those of another file.'
)
a.add_argument("infile", type=str, help="Path to .uvh5 file with cross-correlations to keep and autocorrelations to replace.")
a.add_argument("autofile", type=str, help="Path to .uvh5 file with autocorrelations to substitute in.")
a.add_argument("outfile", type=str, help="Path to output file.")
a.add_argument("--clobber", default=False, action='store_true', help="Overwrite outfile if it already exists")
args = a.parse_args()

# load data
hd = io.HERAData(args.infile)
data, flags, nsamples = hd.read()

# load autos
hda = io.HERAData(args.autofile)
autos, auto_flags, auto_nsamples = hda.read(ant_str='auto')

# replace autocorrelations
for bl in autos:
    data[bl] = autos[bl]
    flags[bl] = auto_flags[bl]
    nsamples[bl] = auto_nsamples[bl]

# write results
hd.update(data=data, flags=flags, nsamples=nsamples)
hd.write_uvh5(args.outfile, clobber=args.clobber, fix_autos=True)
