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

jd=$(get_jd $fn)
int_jd=${jd:0:7}

auto_in_even=zen.${jd}.even.${label}.auto.foreground_filled.uvh5
auto_in_odd=${auto_in_even/even/odd}
auto_out_even=zen.${jd}.even.${label}.auto.foreground_filled_waterfall.tavg.uvh5
auto_out_odd=${auto_out_even/even/odd}

nofg_in_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_res.${data_ext}
nofg_in_odd=${nofg_in_even/even/odd}
nofg_out_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_res.tavg.${data_ext}
nofg_out_odd=${nofg_out_even/even/odd}

fgfilled_in_even=zen.${jd}.even.${label}.waterfall_withforegrounds.${data_ext}
fgfilled_in_odd=${fgfilled_in_even/even/odd}
fgfilled_out_even=zen.${jd}.even.${label}.waterfall_withforegrounds.tavg.${data_ext}
fgfilled_out_odd=${fgfilled_out_even/even/odd}

fgres_in_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds.${data_ext}
fgres_in_odd=${fgres_in_even/even/odd}
fgres_out_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.${data_ext}
fgres_out_odd=${fgres_out_even/even/odd}

tavg_flag=zen.${jd}.${label}.flags.tavg.h5

auto_list_even=`echo zen.${int_jd}.*.even.${label}.auto.foreground_filled.uvh5`
auto_list_odd=`echo zen.${int_jd}.*.odd.${label}.auto.foreground_filled.uvh5`
# time-average autocorrs using waterfall averaging cornerturn.
# even
if [ -e "${auto_in_even}" ]
then
  # do even/odd interleaving.
  echo time_average_baseline_parallelized.py ${auto_in_even} ${auto_out_even} ${auto_list_even} ${t_avg} --rephase --clobber --interleaved_input_data ${auto_in_odd} --interleaved_output_data ${auto_out_odd}
  time_average_baseline_parallelized.py ${auto_in_even} ${auto_out_even} ${auto_list_even} ${t_avg} --rephase --clobber --interleaved_input_data ${auto_in_odd} --interleaved_output_data ${auto_out_odd}
  # odd
  #echo time_average_baseline_parallelized.py ${auto_in_odd} ${auto_out_odd} ${auto_list_odd} ${t_avg} --rephase --clobber
  #time_average_baseline_parallelized.py ${auto_in_odd} ${auto_out_odd} ${auto_list_odd} ${t_avg} --rephase --clobber
else
  echo "${auto_in_even} does not exist!"
fi

# time-average no-fg resids -- use for id weight estimator.
# even
if [ -e "${fgfilled_in_even}" ]
then
  #echo time_average.py ${nofg_in_even} ${nofg_out_even} ${t_avg} --rephase --clobber --flag_output
  #time_average.py ${nofg_in_even} ${nofg_out_even} ${t_avg} --rephase --clobber --flag_output zen.${jd}.${label}.roto_flags.tavg.flags.h5
  # odd
  #echo time_average.py ${nofg_in_odd} ${nofg_out_odd} ${t_avg} --rephase --clobber
  #time_average.py ${nofg_in_odd} ${nofg_out_odd} ${t_avg} --rephase --clobber
  # time-average with-fg filled -- use for signal loss estimation.
  # even / odd interleave
  echo time_average.py ${fgfilled_in_even} ${fgfilled_out_even} ${t_avg} --rephase --clobber --interleaved_input_data ${fgfilled_in_odd} --interleaved_output_data ${fgfilled_out_odd}
  time_average.py ${fgfilled_in_even} ${fgfilled_out_even} ${t_avg} --rephase --clobber --interleaved_input_data ${fgfilled_in_odd} --interleaved_output_data ${fgfilled_out_odd}
  # odd
  #echo time_average.py ${fgfilled_in_odd} ${fgfilled_out_odd} ${t_avg} --rephase --clobber
  #time_average.py ${fgfilled_in_odd} ${fgfilled_out_odd} ${t_avg} --rephase --clobber


  # time-average with-fg resids -- use for dayenu estimator.
  echo time_average.py ${fgres_in_even} ${fgres_out_even} ${t_avg} --rephase --clobber --flag_output ${tavg_flag} --interleaved_input_data  ${fgres_in_odd} --interleaved_output_data ${fgres_out_odd}
  time_average.py ${fgres_in_even} ${fgres_out_even} ${t_avg} --rephase --clobber --flag_output ${tavg_flag} --interleaved_input_data ${fgres_in_odd}  --interleaved_output_data ${fgres_out_odd}
  # odd
  #echo time_average.py ${fgres_in_odd} ${fgres_out_odd} ${t_avg} --rephase --clobber
  #time_average.py ${fgres_in_odd} ${fgres_out_odd} ${t_avg} --rephase --clobber
else
  echo "${fgfilled_in_even} does not exist!"
fi
