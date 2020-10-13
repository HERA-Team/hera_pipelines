#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 3 - external flag file.
# 4 - extra label for the output file.
# 5 - spw0 lower channel to process.
# 6 - spw1 upper channel to process.
# 7 - tol level to subtract foregrounds too
# 8 - standoff delay standoff in ns for filtering window.
# 9 - cache_dir, directory to store cache files in.
fn="${1}"
data_ext="${2}"
flag_ext="${3}"
label="${4}"
spw0="${5}"
spw1="${6}"
tol="${7}"
standoff="${8}"
time_threshold="${9}"
cache_dir="${10}"
# get julian day from file name
jd=$(get_jd $fn)
int_jd=${jd:0:7}

# generate output file name
fn_out=${fn%.uvh5}.${label}.foreground_filtered_waterfall.${data_ext}
# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi

data_files=`echo zen.${int_jd}.*.sum.${data_ext}`
flag_files=`echo zen.${int_jd}.*.xrfi/*${flag_ext}.h5`


fn_in=${fn%.uvh5}.${data_ext}


echo dayenu_delay_filter_run_baseline_parallelized.py ${fn_in} --external_flags ${flag_files} \
  --res_outfilename ${fn_out} --clobber --spw_range ${spw0} ${spw1}\
  --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --skip_flagged_edges\
  --factorize_flags --time_thresh ${time_threshold} --overwrite_data_flags\
  --datafilelist ${data_files}
  #--write_cache --read_cache

  dayenu_delay_filter_run_baseline_parallelized.py ${fn_in} --external_flags ${flag_files} \
    --res_outfilename ${fn_out} --clobber --spw_range ${spw0} ${spw1}\
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --skip_flagged_edges\
    --factorize_flags --time_thresh ${time_threshold} --overwrite_data_flags\
    --datafilelist ${data_files}
