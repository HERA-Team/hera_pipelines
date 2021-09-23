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

epoch_flag_regions = {0: [np.array([12, 20.55]) * np.pi / 12],
                      1: [np.array([0, .284]) * np.pi / 12,  np.array([11.32, 24]) * np.pi / 12],
                      2: [np.array([0, 3.75]) * np.pi / 12,  np.array([14.51, 24]) * np.pi / 12],
                      3: [np.array([0, 6.175]) * np.pi / 12, np.array([17.09, 24]) * np.pi / 12]}

for epoch in range(4):
    data_files = sorted(glob.glob(f'/lustre/aoc/projects/hera/H1C_IDR3/IDR3_2/LSTBIN/epoch_{epoch}/preprocess/zen.grp1.of1.LST*sum.PX.uvh5'))
    _, _, file_lst_arrays, _ = io.get_file_times(data_files)
    for df, lsts in zip(data_files, file_lst_arrays):
        to_flag = np.zeros(len(lsts), dtype=bool)
        for flag_region in epoch_flag_regions[epoch]:
            to_flag |= ((lsts >= flag_region[0]) & (lsts <= flag_region[1]))
        if np.any(to_flag):
            print(f'\nNow loading {df}')
            hd = io.HERAData(df)
            _, flags, _ = hd.read()
            if np.all(hd.flag_array):
                print('    File totally flagged. Moving on.')
                continue
            for bl in flags:
                flags[bl][to_flag, :] = True
            hd.update(flags=flags)
            print('    Flags updated.')
            hd.write_uvh5(df, clobber=True)
