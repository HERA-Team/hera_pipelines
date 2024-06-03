#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

input1=zen.${jd}.sum.flagged_abs.calfits
input2=zen.${jd}.sum.omni.calfits
output=zen.${jd}.sum.red_degen.calfits

cmd="multiply_gains.py ${input1} ${input2} ${output} --divide_gains --clobber"

echo ${cmd}
${cmd}
