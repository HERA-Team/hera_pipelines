#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
### cal smoothing parameters - see hera_cal.smooth_cal for details
# 2 - identifying label for pipeline settings.
# 3 - output data extension.
# 4 - baselines to load at once.
# 5 - extension of flags to use.
# 5 - polarizations to output.
# POLARIZATION SELECTION HAS NOT YET BEEN IMPLEMENTED IN HERA-CAL

fn="${1}"
label="${2}"
output_ext="${3}"
nbl_per_load="${4}"
flag_ext="${5}"
pols="${@:5}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

input_file=${fn%.uvh5}.smooth_avg_vis.uvh5

# get flag files
flag_files=`echo zen.${int_jd}.*.stage_1_xrfi/*${flag_ext}.h5`
outfile = zen.${jd}.

#calibrate sum.
echo apply_waterfall_flags.py  ${fn} ${outfile} ${flag_files}\
--nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile} --overwrite_data_flags\
--flag_only
