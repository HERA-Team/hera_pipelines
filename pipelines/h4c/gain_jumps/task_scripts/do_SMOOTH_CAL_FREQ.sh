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

input=zen.${jd}.${sd}.${label}.model_cal.calfits

cmd="smooth_cal.py ${input} --infile_replace .model_cal. \
     --outifle_replace .model_cal_smooth_freq. --clobber \
     --pick_refant --verbose --method DPSS --skip_flagged_edges --axis freq"

echo ${cmd}
${cmd}
