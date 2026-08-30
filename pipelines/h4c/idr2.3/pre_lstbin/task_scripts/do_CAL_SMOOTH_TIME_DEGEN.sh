#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"
time_scale="${3}"
tol="${4}"
time_threshold="${5}"
ant_threshold="${6}"
lst_blacklists="${@:7}"



jd=$(get_jd $fn)
int_jd=${jd:0:7}

calfiles=`echo zen.${int_jd}.*.sum.${label}.red_degen.calfits`

cmd="smooth_cal_run.py ${calfiles} --infile_replace .red_degen. \
     --outfile_replace .red_degen_time_smoothed. --clobber \
     --pick_refant --verbose --method DPSS --axis time --time_threshold ${time_threshold} \
     --ant_threshold ${ant_threshold} --time_scale ${time_scale} --lst_blacklists ${lst_blacklists}"

echo ${cmd}
${cmd}
