#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
time_scale="${2}"
tol="${3}"
time_threshold="${4}"
ant_threshold="${5}"
lst_blacklists="${@:6}"



jd=$(get_jd $fn)
int_jd=${jd:0:7}

calfiles=`echo zen.${int_jd}.*.red_degen.calfits`

input=zen.${jd}.sum.red_degen.calfits

cmd="smooth_cal_run.py ${input} --infile_replace .red_degen. \
     --outfile_replace .red_degen_time_smoothed. --clobber \
     --pick_refant --verbose --method DPSS --axis freq --time_threshold ${time_threshold} \
     --ant_threshold ${ant_threshold} --time_scale ${time_scale} --lst_blacklists ${lst_blacklists}"

echo ${cmd}
${cmd}
