#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# This script averages data in time.
# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - template file name (template for time chunk to reconstitute).
# 2 - data extension
# 2 - output label for identifying file.
# 3 - number of seconds to average in time.

fn="${1}"
label="${2}"
t_avg="${3}"
grpstr="${4}"
#n_avg="${5}"

#if [ "${t_avg}" = "none" ]
#then
#t_avg_arg="--n_avg ${n_avg}"
#else
t_avg_arg="--t_avg ${t_avg}"
#fi

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`



sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
    auto_list=`echo zen.${grpstr}.LST.*.${sd}.${label}.autos.foreground_filled.chunked.uvh5`
    auto_in=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.foreground_filled.chunked.uvh5
    auto_out=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.foreground_filled.waterfall.tavg.uvh5

    fg_in=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.chunked.uvh5
    fg_out=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.waterfall.tavg.uvh5
    fg_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered.chunked.uvh5`
  # time-average autocorrs using waterfall averaging cornerturn.
  # even
  if [ -e "${auto_in}" ]
  then
    echo time_average.py ${auto_list} ${auto_out} --cornerturnfile ${auto_in} \
     --rephase --clobber --t_avg ${t_avg}
     time_average.py ${auto_list} ${auto_out} --cornerturnfile ${auto_in} \
      --rephase --clobber --t_avg ${t_avg}
  else
    echo "${auto_in} does not exist!"
  fi

  # time-average intpainted, xtalk-filtered data.
  # even
  if [ -e "${fg_in}" ]
  then
    echo time_average.py ${fg_files} ${fg_out} --cornerturnfile ${fg_in} --t_avg ${t_avg} --clobber
    time_average.py ${fg_files} ${fg_out} --cornerturnfile ${fg_in} --t_avg ${t_avg} --clobber
  else
    echo "${fg_in} does not exist!"
  fi

done
