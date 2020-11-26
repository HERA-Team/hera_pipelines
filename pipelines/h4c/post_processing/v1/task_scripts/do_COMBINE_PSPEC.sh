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


fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds.pspec.h5`
input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds.pspec.h5
combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds.pspec.h5
for i in "${!fragments[@]}"; do
   if [[ "${fragments[$i]}" = "${input}" ]]; then
       fragment_position="${i}";
   fi

if [ "${fragment_position}" = "0" ]; then
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi

if [ "${fragment_position}" = "1" ]; then
  fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.pspec.h5`
  input=${fragments[0]}
  combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds.tavg.pspec.h5
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi

if [ "${fragment_position}" = "2" ]; then
  fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds.fullband.pspec.h5`
  input=${fragments[0]}
  combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds.fullband.pspec.h5
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi

if [ "${fragment_position}" = "3" ]; then
  fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.fullband.pspec.h5`
  input=${fragments[0]}
  combined=zen.${int_jd}.${label}.xtalk_filtered_withforegrounds.tavg.fullband.pspec.h5
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi


if [ "${fragment_position}" = "4" ]; then
  fragments=`echo zen.${int_jd}.*.${label}.waterfall_withforegrounds.pspec.h5`
  input=${fragments[0]}
  combined=zen.${int_jd}.${label}.withforegrounds.pspec.h5
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi

if [ "${fragment_position}" = "5" ]; then
  fragments=`echo zen.${int_jd}.*.${label}.waterfall_withforegrounds.tavg.pspec.h5`
  input=${fragments[0]}
  combined=zen.${int_jd}.${label}.withforegrounds.tavg.pspec.h5
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi


if [ "${fragment_position}" = "6" ]; then
  fragments=`echo zen.${int_jd}.*.${label}.waterfall_withforegrounds.fullband.pspec.h5`
  input=${fragments[0]}
  combined=zen.${int_jd}.${label}.withforegrounds.fullband.pspec.h5
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi


if [ "${fragment_position}" = "7" ]; then
  fragments=`echo zen.${int_jd}.*.${label}.waterfall_withforegrounds.tavg.fullband.pspec.h5`
  input=${fragments[0]}
  combined=zen.${int_jd}.${label}.withforegrounds.tavg.fullband.pspec.h5
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi

# only combine dayenu pspec if they exist.
  #fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds.day.pspec.h5`
  #input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds.day.pspec.h5
  #combined=zen.${int_jd}.${label}.xtalk_filtered_waterfall_withforegrounds.day.pspec.h5
  #echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  #combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber


  #fragments=`echo zen.${int_jd}.*.${label}.xtalk_filtered_waterfall_withforegrounds.day.tavg.fullband.pspec.h5`
  #input=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds.day.tavg.fullband.pspec.h5
  #combined=zen.${int_jd}.${label}.xtalk_filtered_waterfall_withforegrounds.day.tavg.fullband.pspec.h5
  #echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  #combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
if [ "${fragment_position}" = "8" ]; then
  fragments=`echo zen.${int_jd}.*.${label}.auto.tavg.fullband.pspec.h5`
  input=${fragments[0]}
  combined=zen.${int_jd}.${label}.auto.tavg.fullband.pspec.h5
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi

if [ "${fragment_position}" = "9" ]; then
  fragments=`echo zen.${int_jd}.*.${label}.auto.tavg.pspec.h5`
  input=${fragments[0]}
  combined=zen.${int_jd}.${label}.auto.tavg.pspec.h5
  echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
fi
