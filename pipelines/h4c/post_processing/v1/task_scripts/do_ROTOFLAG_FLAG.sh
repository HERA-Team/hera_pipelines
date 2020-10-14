#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - file name
# 2 - percentile_freq
# 3 - percentile_time
# 4 - niters
# 5 - output_label
# 6 - data extension


fn="${1}"
label="${2}"
percentile_freq="${3}"
percentile_time="${4}"
niters="${5}"
cal_ext="${6}"


jd=$(get_jd $fn)
int_jd=${jd:0:7}

# get metric files
this_metric=zen.${jd}.${label}.roto_flag.metrics.h5
metrics=`echo zen.${int_jd}.*.${label}.roto_flag.metrics.h5`
flags=`echo zen.${int_jd}.*.${label}.roto_flag.flags.h5`
cal_files=`echo zen.${int_jd}.*.${label}.chunked.${cal_ext}`

if [ -e "${this_metric}" ]
then
  echo roto_flag_run.py --data_files ${metrics} \
                        --flag_files ${flags} \
                        --cal_files ${cal_files} \
                        --flag_percentile_freq ${percentile_freq} \
                        --flag_percentile_time ${percentile_time} \
                        --output_label ${label}.roto_flag \
                        --fname ${this_metric} \
                        --niters ${niters} --clobber --flag_only

  roto_flag_run.py --data_files ${metrics} \
                   --flag_files ${flags} \
                   --cal_files ${cal_files} \
                   --flag_percentile_freq ${percentile_freq} \
                   --flag_percentile_time ${percentile_time} \
                   --output_label ${label}.roto_flag \
                   --fname ${this_metric} \
                   --niters ${niters} --clobber --flag_only
else
  echo "${this_metric} does not exist!"
fi
