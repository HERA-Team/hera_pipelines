#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional parameters passed as defined in the configuration file:
# 1 - base filename
fn=${1}
infile=${fn%.xx.HH.uv}.sum.uvh5
outfile=${fn%.xx.HH.uv}.sum.smooth_calibrated.uvh5
sc_file=${fn%.xx.HH.uv}.sum.smooth_abs.calfits

echo apply_cal.py ${infile} ${outfile} --new_cal ${sc_file} --vis_units Jy --clobber 
apply_cal.py ${infile} ${outfile} --new_cal ${sc_file} --vis_units Jy --clobber 
