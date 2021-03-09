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
data_ext="${2}"
label="${3}"
t_avg="${4}"
grpstr="${5}"
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
    auto_list=`echo zen.${grpstr}.LST.*.${sd}.${label}.autos.foreground_filled.uvh5`
    auto_in=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.foreground_filled.uvh5
    auto_out=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.waterfall.tavg.uvh5
    fg_in=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered_waterfall.${data_extp}
    fg_out=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered_waterfall.tavg.${data_extp}
    tavg_flag=zen.${grpstr}.LST.${lst}.${label}.flags.tavg.h5

  # time-average autocorrs using waterfall averaging cornerturn.
  # even
  if [ -e "${auto_in}" ]
  then
    echo time_average_baseline_parallelized.py ${auto_in} ${auto_out} ${auto_list} \
     --rephase --clobber --t_avg ${t_avg}
     time_average_baseline_parallelized.py ${auto_in} ${auto_out} ${auto_list} \
      --rephase --clobber --t_avg ${t_avg}
  else
    echo "${auto_in} does not exist!"
  fi

  # time-average intpainted, xtalk-filtered data.
  # even
  if [ -e "${fg_in}" ]
  then
    echo time_average.py ${fg_in} ${fg_out} --rephase --clobber \
    --flag_output ${tavg_flag} --t_avg ${t_avg}
    time_average.py ${fg_in} ${fg_out} --rephase --clobber \
    --flag_output ${tavg_flag} --t_avg ${t_avg}
  else
    echo "${fg_in} does not exist!"
  fi

  fg_in=zen.${grpstr}.LST.${lst}.${sd}.${label}.waterfall.uvh5
  fg_out=zen.${grpstr}.LST.${lst}.${sd}.${label}.waterfall.tavg.uvh5
  # time average non-xtalk filtered data
  if [ -e "${fg_in}" ]
  then
    echo time_average.py ${fg_in} ${fg_out} --rephase --clobber \
    --flag_output ${tavg_flag} --t_avg ${t_avg}
    time_average.py ${fg_in} ${fg_out} --rephase --clobber \
    --flag_output ${tavg_flag} --t_avg ${t_avg}
  else
    echo "${fg_in} does not exist!"
  fi

done
