#!/bin/bash
set -e

# This script uses avg_baselines.py to average calibrated data over baselines for autos, crosses, and both, keeping pols separate.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional parameters passed as defined in the configuration file:
# 1 - base filename
fn=${1}
infile=${fn%.xx.HH.uv}.sum.final_calibrated.uvh5

# loop over three average types: autocorrelations, cross-correlations, and all baselines
for ant_str in auto cross all; do
    cmd = "python ${src_dir}/avg_baselines.py ${infile} ${infile%.uvh5}.avg_${ant_str}.uvh5 --ant_str ${ant_str} --clobber"
    echo $cmd
    $cmd
done
