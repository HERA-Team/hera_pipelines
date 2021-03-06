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
grpstr="${3}"

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`


sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  fragments=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered.waterfall.tavg.fullband.pspec.h5`
  input=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.waterfall.tavg.fullband.pspec.h5
  combined=zen.${grpstr}.LST.${sd}.${label}.xtalk_filtered.waterfall.tavg.fullband.pspec.h5
  i=0
  for f in zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered.waterfall.tavg.fullband.pspec.h5; do
     if [[ "${f}" = "${input}" ]]; then
         fragment_position="${i}";
     fi
     i=$(($i+1))
  done

  if [ "${fragment_position}" = "3" ]; then
    fragments=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered.waterfall.tavg.fullband.pspec.h5`
    input=`ls zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered.waterfall.tavg.fullband.pspec.h5 | head -1`
    combined=zen.${grpstr}.LST.${sd}.${label}.xtalk_filtered.waterfall.tavg.fullband.pspec.h5
    echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
    combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  fi

  if [ "${fragment_position}" = "4" ]; then
    fragments=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered.waterfall.tavg.pspec.h5`
    input=`ls zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered.waterfall.tavg.pspec.h5 | head -1`
    combined=zen.${grpstr}.LST.${sd}.${label}.xtalk_filtered.waterfall.tavg.pspec.h5
    echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
    combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  fi

  if [ "${fragment_position}" = "8" ]; then
    fragments=`echo zen.${grpstr}.LST.*.${sd}.${label}.auto.waterfall.tavg.fullband.pspec.h5`
    input=`ls zen.${grpstr}.LST.*.${sd}.${label}.auto.waterfall.tavg.fullband.pspec.h5 | head -1`
    combined=zen.${grpstr}.LST.${sd}.${label}.auto.tavg.fullband.pspec.h5
    echo combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
    combine_pspec_containers.py ${fragments} ${input} ${combined} --clobber
  fi
done
