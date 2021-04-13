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
label="${3}"
t_avg="${4}"

t_avg_arg="--t_avg ${t_avg}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}


parities=("0" "1")
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
# time average time-inpainted files and xtalk-filtered files.
  input_file=`echo zen.${jd}.${sd}.${label}.time_inpainted.waterfall.uvh5`
  output_file=zen.${jd}.${sd}.${label}.time_inpainted.waterfall.tavg.uvh5
  echo time_average.py ${input_file} ${output_file} --tavg ${t_avg} --dont_wgt_by_nsample --clobber
  time_average.py ${input_file} ${output_file} --tavg ${t_avg} --dont_wgt_by_nsample --clobber

  input_file=`echo zen.${jd}.${sd}.${label}.xtalk_filtered.waterfall.uvh5`
  output_file=zen.${jd}.${sd}.${label}.xtalk_filtered.waterfall.tavg.uvh5
  echo time_average.py ${input_file} ${output_file} --tavg ${t_avg} --dont_wgt_by_nsample --clobber
  time_average.py ${input_file} ${output_file} --tavg ${t_avg} --dont_wgt_by_nsample --clobber
done
