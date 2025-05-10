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

# deletes all interim data files of (h4c_idr3) validation rtp stage
# saves only the original mock data zen*sum.uvh5 files and
# the smooth calibration solutions zen*smooth_abs.calfits



# remove absolute calibration files
rm -rf zen.${jd}.*.${label}*.sum.abs.calfits
# remove omni calibration files
rm -rf zen.${jd}.*.${label}*.sum.omni.calfits
# remove omni calibration vis files
rm -rf zen.${jd}.*.${label}*.omni_vis.uvh5
# remove redundant calibration meta data
rm -rf zen.${jd}.*.${label}*.sum.redcal_meta.hdf5
