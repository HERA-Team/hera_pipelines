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

input=zen.${jd}.${sd}.${label}.model_cal.calfits

cmd="smooth_cal_run.py ${input} --infile_replace .model_cal. \
     --outfile_replace .model_cal_smooth_freq. --clobber \
     --pick_refant --verbose --method DPSS --axis freq"

echo ${cmd}
${cmd}
