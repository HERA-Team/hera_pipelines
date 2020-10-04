#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

#the args are
# 1 - input file name.
# 2- label

# define input arguments
fn="${1}"
label="${2}"
jd=$(get_jd $fn)
int_jd=${jd:0:7}

fragments=`echo *.${label}.xtalk_filtered_waterfall_noforegrounds_res.uvp`
intput=zen.${jd}.${label}.xtalk_filtered_waterfall_noforegrounds_res.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_waterfall_noforegrounds_res.uvp
combine_pspec_containers.py ${fagments} ${input} ${combined} --clobber

fragments=`echo *.${label}.xtalk_filtered_waterfall_withforegrounds_res.uvp`
intput=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.uvp
combine_pspec_containers.py ${fagments} ${input} ${combined} --clobber

fragments=`echo *.${label}.xtalk_filtered_waterfall_withforegrounds_filled.uvp`
intput=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.uvp
combine_pspec_containers.py ${fagments} ${input} ${combined} --clobber
