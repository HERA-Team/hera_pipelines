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

# make outfile
outfile=${fn%.uvh5}.red_avg.uvh5

echo apply_cal.py ${fn} ${outfile} --nbl_per_load ${nbl_per_load} --redundant_average --clobber
apply_cal.py ${fn} ${outfile} --nbl_per_load ${nbl_per_load} --redundant_average --clobber
