#!/usr/bin/env python
"""
hand_flag_epoch_edge_times.py
-----------------------------------------
Copyright (c) 2021 The HERA Collaboration

This hacky script hand-flags epoch edge times for H1C IDR3 which often exhibit failures
in crosstalk subtraction.
"""

import numpy as np
import glob
from hera_cal import io
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("epoch", type=int, help="Which epoch to hand-flag.")
args = parser.parse_args()

epoch_flag_regions = {0: [np.array([12, 20.54]) * np.pi / 12],
                      1: [np.array([11.32, 24]) * np.pi / 12],
                      2: [np.array([0, 3.935]) * np.pi / 12,  np.array([14.51, 24]) * np.pi / 12],
                      3: [np.array([0, 6.085]) * np.pi / 12]}
assert args.epoch in epoch_flag_regions

data_files = sorted(glob.glob(f'/lustre/aoc/projects/hera/Validation/test-4.1.0/LSTBIN/epoch_{args.epoch}/zen.grp1.of1.LST*sum.uvh5'))
_, _, file_lst_arrays, _ = io.get_file_times(data_files)
for df, lsts in zip(data_files, file_lst_arrays):
    to_flag = np.zeros(len(lsts), dtype=bool)
    for flag_region in epoch_flag_regions[args.epoch]:
        to_flag |= ((lsts >= flag_region[0]) & (lsts <= flag_region[1]))
        to_flag |= ((lsts - 2*np.pi >= flag_region[0]) & (lsts - 2*np.pi <= flag_region[1]))
    if np.any(to_flag):
        print(f'\nNow loading {df}')
        hd = io.HERAData(df)
        if "Epoch edge flags added by hand" in hd.history:
           print('    File already hand-flagged. Moving on.')
           continue
        _, flags, _ = hd.read()
        if np.all(hd.flag_array):
            print('    File totally flagged. Moving on.')
            continue
        for bl in flags:
            flags[bl][to_flag, :] = True
        hd.update(flags=flags)
        print('    Flags updated.')
        hd.history += '\n\nEpoch edge flags added by hand.\n\n'
        hd.write_uvh5(df, clobber=True)
