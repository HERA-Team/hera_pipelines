#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
freq_scale="${2}"
tol="${3}"
freq_threshold="${4}"
ant_threshold="${5}"



jd=$(get_jd $fn)
int_jd=${jd:0:7}

calfiles=`echo zen.${int_jd}.*.abs_degen_time_smoothed.calfits`

input=zen.${jd}.sum.freq_smoothed_abs_degen_time_smoothed.calfits

cmd="smooth_cal_run.py ${calfiles} --infile_replace .abs_degen_time_smoothed. \
     --outfile_replace .freq_smoothed_abs_degen_time_smoothed. --clobber \
     --pick_refant --verbose --method DPSS --axis freq --freq_threshold ${freq_threshold} \
     --ant_threshold ${ant_threshold} --freq_scale ${freq_scale}"

echo ${cmd}
${cmd}
