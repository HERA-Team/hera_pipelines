#! /bin/bash

# this cleanup script will only leaave
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
# get rid of all the waterfall files associated with this run.
rm -rf zen.${jd}.*.${label}*waterfall*h5
# also get rid of the chunked files.
rm -rf zen.${jd}.*.${label}*chunked*h5
# the following should be commented for devel mode.


# remove power spectra
rm -rf zen.${jd}.*.${label}*pspec.*
# remove tavg files
rm -rf zen.${jd}.*.${label}*tavg.*
# remove time inpainted files.
rm -rf zen.${jd}.*.${label}*time_inpainted.*
# remove foreground model files.
rm -rf zen.${jd}.*.${label}*foreground_model.uvh5
# remove foreground res files.
rm -rf zen.${jd}.*.${label}*foreground_res.uvh5
# remove foreground filled files.
rm -rf zen.${jd}.*.${label}*foreground_filled.uvh5
# remove filled flag files.
rm -rf zen.${jd}.*.${label}*filled_flags*.uvh5
