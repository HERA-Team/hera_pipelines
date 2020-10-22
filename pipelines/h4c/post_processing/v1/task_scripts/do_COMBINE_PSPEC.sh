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



#fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_noforegrounds_res.fullband_ps.uvp`
#input=zen.${jd}.${label}.xtalk_filtered_waterfall_noforegrounds_res.fullband_ps.uvp
#combined=zen.${int_jd}.${label}.xtalk_filtered_noforegrounds_res.fullband_ps.uvp
#echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
#combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


#fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_noforegrounds_res.fullband_ps.tavg.uvp`
#input=zen.${jd}.${label}.xtalk_filtered_waterfall_noforegrounds_res.fullband_ps.tavg.uvp
#combined=zen.${int_jd}.${label}.xtalk_filtered_noforegrounds_res.fullband_ps.tavg.uvp
#echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
#combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_res.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_res.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber

fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_res.tavg.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.tavg.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_res.tavg.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_res.fullband_ps.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.fullband_ps.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_res.fullband_ps.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_res.fullband_ps.tavg.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.fullband_ps.tavg.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_res.fullband_ps.tavg.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_filled.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_filled.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber

fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_filled.tavg.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.tavg.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_filled.tavg.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_filled.fullband_ps.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.fullband_ps.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_filled.fullband_ps.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber

fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_filled.fullband_ps.tavg.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.fullband_ps.tavg.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_filled.fullband_ps.tavg.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_res.day.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.tavg.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.tavg.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_res.day.tavg.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.fullband_ps.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.fullband_ps.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_res.day.fullband_ps.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.fullband_ps.tavg.uvp`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.fullband_ps.tavg.uvp
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds_res.day.fullband_ps.tavg.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber



fragments=`echo zen.${int_jd}.*.${label}.auto.fullband_ps.tavg.uvp`
input=zen.${jd}.${label}.auto.fullband_ps.tavg.uvp
combined=zen.${int_jd}.${label}.auto.fullband_ps.tavg.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


fragments=`echo zen.${int_jd}.*.${label}.auto.tavg.uvp`
input=zen.${jd}.${label}.auto.tavg.uvp
combined=zen.${int_jd}.${label}.auto.tavg.uvp
echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
