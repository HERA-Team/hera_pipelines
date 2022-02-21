#!/bin/bash
set -e

# This script applies both smooth_cal (which is one per file) and ref_cal (which is one per day) to the original data.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional parameters passed as defined in the configuration file:
# 1 - base filename
fn=${1}
infile=${fn%.xx.HH.uv}.sum.uvh5
smooth_cal_file=${fn%.xx.HH.uv}.sum.smooth_abs.calfits
jd_int=$(get_int_jd ${fn})
ref_cal_file=${fn%${jd_int}.*}${jd_int}.time_avg_ref_cal.calfits
outfile=${fn%.xx.HH.uv}.sum.final_calibrated.uvh5

echo apply_cal.py ${infile} ${outfile} --new_cal ${smooth_cal_file} --vis_units Jy --clobber 
apply_cal.py ${infile} ${outfile} --new_cal ${smooth_cal_file} --vis_units Jy --clobber 

echo apply_cal.py ${outfile} ${outfile} --new_cal ${ref_cal_file} --vis_units Jy --clobber 
apply_cal.py ${outfile} ${outfile} --new_cal ${ref_cal_file} --vis_units Jy --clobber 
