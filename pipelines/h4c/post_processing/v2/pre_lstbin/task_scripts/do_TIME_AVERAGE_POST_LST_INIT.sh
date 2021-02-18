#! /bin/bash
set -e

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
#n_avg="${5}"

#if [ "${t_avg}" = "none" ]
#then
#t_avg_arg="--n_avg ${n_avg}"
#else
t_avg_arg="--t_avg ${t_avg}"
#fi


parities=("0" "1")
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  for parity in ${parities[@]}
  do
    data_extp=${data_ext/.uvh5/.${parity}.uvh5}
    auto_list=`echo *.${sd}.${label}.auto.foreground_filled.uvh5`
    auto_in=zen.grp1.of1.LST.${lst}.${sd}.${label}.auto.foreground_filled.uvh5
    auto_out=zen.grp1.of1.LST.${jd}.${sd}.${label}.auto.waterfall.tavg.uvh5
    fg_in=zen.${jd}.${sd}.${label}.xtalk_filtered_res.${data_extp}
    fg_out=zen.${jd}.${sd}.${label}.xtalk_filtered_res.tavg.${data_extp}
    tavg_flag=zen.${jd}.${label}.flags.tavg.h5

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
    echo time_average_baseline_parallelized.py ${fg_in} ${fg_out} --rephase --clobber \
    --flag_output ${tavg_flag} --t_avg ${t_avg}
    time_average_baseline_parallelized.py ${fg_in} ${fg_out} --rephase --clobber \
    --flag_output ${tavg_flag} --t_avg ${t_avg}
  else
    echo "${fg_in} does not exist!"
  fi

  fg_in=zen.${jd}.${sd}.${label}.waterfall.${data_extp}
  fg_out=zen.${jd}.${sd}.${label}.waterfall.tavg.${data_extp}
  # time average non-xtalk filtered data
  if [ -e "${fg_in}" ]
  then
    echo time_average_baseline_parallelized.py ${fg_in} ${fg_out} --rephase --clobber \
    --flag_output ${tavg_flag} --t_avg ${t_avg}
    time_average_baseline_parallelized.py ${fg_in} ${fg_out} --rephase --clobber \
    --flag_output ${tavg_flag} --t_avg ${t_avg}
  else
    echo "${fg_in} does not exist!"
  fi

  done
done
