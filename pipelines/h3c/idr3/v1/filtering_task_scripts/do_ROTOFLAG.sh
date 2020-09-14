#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - file name
# 3 - percentile_freq
# 4 - percentile_time
# 5 - niters
# 6 - output_label
# 7 - yaml_dir
# 9 - data extension
# 10 - kf_size
# 11 - kt_size

fn="${1}"
percentile_freq="${2}"
percentile_time="${3}"
niters="${4}"
label="${5}"
data_ext="${6}"
kf_size="${7}"
kt_size="${8}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

# get xtalk waterfall file
xtalk_wf=${fn%.uvh5}.${label}.xtalk_filtered_waterfall.${data_ext}



echo roto_flag_run.py --data_files ${xtalk_wf} \
                      --flag_percentile_freq ${percentile_freq} \
                      --flag_percentile_time ${percentile_time} \
                      --output_label ${label}.roto_flag \
                      --kf_size ${kf_size} \
                      --kt_size ${kt_size} \
                      --niters ${niters} --clobber --metric_only

roto_flag_run.py --data_files ${xtalk_wf} \
                 --flag_percentile_freq ${percentile_freq} \
                 --flag_percentile_time ${percentile_time} \
                 --output_label ${label}.roto_flag \
                 --kf_size ${kf_size} \
                 --kt_size ${kt_size} \
                 --niters ${niters} --clobber --metric_only
