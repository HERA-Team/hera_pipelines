#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright (c) 2019 the HERA Project
# Licensed under the MIT License

import sys
from hera_qm import utils
from pyuvdata import UVCal

cal_file = sys.argv[1]
yaml_file = sys.argv[2]

#print('data')
#print(cal_file)
#print('yaml')
#print(yaml_file)
uv = UVCal()
uv.read_calfits(cal_file)
uv = utils.apply_yaml_flags(uv, yaml_file, ant_indices_only=True, flag_ants=True, flag_freqs=False, flag_times=False, throw_away_flagged_ants=True)
uv.write_calfits(cal_file, clobber=True)
