#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
fn="${1}"

# get relevant files, removing base extension and appending new extensions
omni_cal=`echo ${fn%.*}.omni.calfits`
smooth_abs_cal=`echo ${fn%.*}.smooth_abs.calfits`
omni_vis=`echo ${fn%.*}.omni_vis.uvh5`
smooth_abs_vis=`echo ${fn%.*}.smooth_abs_vis.uvh5`

# Update omnical visibility solution with smooth_abs calibration
echo apply_cal.py ${omni_vis} ${smooth_abs_vis} --new_cal ${smooth_abs_cal} --old_cal ${omni_cal} --redundant_solution --clobber --vis_units Jy
apply_cal.py ${omni_vis} ${smooth_abs_vis} --new_cal ${smooth_abs_cal} --old_cal ${omni_cal} --redundant_solution --clobber --vis_units Jy
