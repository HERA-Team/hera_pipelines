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

calfile=${fn%.uvh5}.smooth_abs.calfits
outfile=${fn%.uvh5}.smooth_avg_vis.uvh5
difffile=${fn%.sum.uvh5}.diff.uvh5
diffoutfile=${fn%.sum.uvh5}.diff.smooth_avg_vis.uvh5

echo apply_cal.py ${fn} ${outfile} --nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile}
apply_cal.py ${fn} ${outfile} --nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile}

echo apply_cal.py ${difffile} ${diffoutfile} --nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile}
apply_cal.py ${difffile} ${diffoutfile} --nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile}
