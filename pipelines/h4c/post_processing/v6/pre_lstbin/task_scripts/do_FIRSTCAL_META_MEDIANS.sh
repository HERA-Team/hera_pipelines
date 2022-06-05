#!/bin/bahs
set -e
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn="${1}"
label="${2}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}


meta_list=zen.${int_jd}.*.sum.redcal_meta.hdf5
firstcal_file_list=zen.${int_jd}.*.sum.first.calfits
output_ext=".${label}.redcal_meta.median_phases.hdf5"

cmd="run_median_nightly_firstcal_delays.py ${meta_list} --output_ext ${output_ext} --offsets_in_firstcal --firstcal_file_list ${firstcal_file_list}"
echo ${cmd}
${cmd}
