#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - data extension
# 3 - external flag file.
# 4 - extra label for the output file.
# 5 - tol level to subtract foregrounds too
# 6 - standoff delay standoff in ns for filtering window.
# 7 - time threshold to factorize_flags on.
# 8 - cache_dir, directory to store cache files in.
# 9 - yaml_dir, directory of yaml file.

fn="${1}"
data_ext="${2}"
flag_ext="${3}"
label="${4}"
tol="${5}"
standoff="${6}"
time_threshold="${7}"
cache_dir="${8}"
yaml_dir="${9}"
# get julian day from file name
jd=$(get_jd $fn)
int_jd=${jd:0:7}
yaml_file=${yaml_dir}/${int_jd}.yaml

# generate output file name
fn_out=${fn%.uvh5}.${label}.foreground_filtered_waterfall.${data_ext}
# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi

data_files=`echo zen.${int_jd}.*.sum.${label}.chunked.${data_ext}`
flag_files=`echo zen.${int_jd}.*.xrfi/*${flag_ext}.h5`


fn_in=zen.${jd}.sum.${label}.chunked.${data_ext}

if [ -e "${fn_in}" ]
then
echo dayenu_delay_filter_run_baseline_parallelized.py ${fn_in} --external_flags ${flag_files} \
  --res_outfilename ${fn_out} --clobber --a_priori_flag_yaml ${yaml_file}\
  --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --skip_flagged_edges\
  --factorize_flags --time_thresh ${time_threshold} --overwrite_data_flags\
  --datafilelist ${data_files} --verbose
  #--write_cache --read_cache

  dayenu_delay_filter_run_baseline_parallelized.py ${fn_in} --external_flags ${flag_files} \
    --res_outfilename ${fn_out} --clobber --a_priori_flag_yaml ${yaml_file}\
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --skip_flagged_edges\
    --factorize_flags --time_thresh ${time_threshold} --overwrite_data_flags\
    --datafilelist ${data_files} --verbose
else
  echo "${fn_in} does not exists!"
fi
