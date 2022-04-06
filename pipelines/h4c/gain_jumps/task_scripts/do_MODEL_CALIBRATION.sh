#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn="${1}"
label="${2}"


jd=$(get_jd $fn)
int_jd=${jd:0:7}

sd="sum"

model=zen.${jd}.${sd}.${label}.red_avg.chunked.foreground_model.time_inpainted.uvh5
data=zen.${jd}.${sd}.${label}.chunked.uvh5
output=zen.${jd}.${sd}.${label}.model_cal.calfits

cmd="model_calibration_run.py ${data} ${model} ${output} --auto_file ${data} --inflate_model_by_redundancy --constrain_model_to_data_ants --tol 1e-6"
echo ${cmd}
${cmd}
