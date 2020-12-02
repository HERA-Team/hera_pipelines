#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - baselines to load at once.

fn="${1}"
nbl_per_load="${2}"

# make sure input file is correct uvh5 file
uvh5_fn=$(remove_pol $fn)
uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software

calfile=${uvh5_fn%.uvh5}.smooth_abs.calfits
outfile=${uvh5_fn%.uvh5}.smooth_avg_vis.uvh5

echo apply_cal.py ${uvh5_fn} ${outfile} --nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile}
apply_cal.py ${uvh5_fn} ${outfile} --nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile}
