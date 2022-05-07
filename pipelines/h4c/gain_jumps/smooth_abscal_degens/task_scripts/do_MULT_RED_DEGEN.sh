#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

input1=zen.${jd}.sum.red_degen_time_smoothed.calfits
input2=zen.${jd}.sum.omni.calfits
output=zen.${jd}.sum.freq_smoothed_abs_degen_time_smoothed.calfits

cmd="multiply_gains.py ${input1} ${input2} ${output} --clobber"

echo ${cmd}
${cmd}
