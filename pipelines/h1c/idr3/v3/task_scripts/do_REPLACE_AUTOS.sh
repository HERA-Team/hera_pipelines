#!/bin/bash
set -e

# This script uses avg_baselines.py to average calibrated data over baselines for autos, crosses, and both, keeping pols separate.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional parameters passed as defined in the configuration file:
# 1 - base filename
fn=${1}

# get file to update and file to draw autos from
infile=${fn%.xx.HH.uv}.sum.final_calibrated.dpss_res.xtalk_filt.uvh5
autofile=${fn%.xx.HH.uv}.sum.final_calibrated.uvh5

# run script
echo python ${src_dir}/replace_autos.py ${infile} ${autofile} ${infile} --clobber
python ${src_dir}/replace_autos.py ${infile} ${autofile} ${infile} --clobber
