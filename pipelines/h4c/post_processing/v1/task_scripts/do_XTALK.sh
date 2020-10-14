#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - extension for files to read and write.
# 3 - label for files to read and write..
# 5 - tol level to subtract foregrounds too
# 6 - First xtalk filter coefficient. Remove power below fringe-rates of fc0 * bl_len + fc1.
# 7 - Second xtalk filter coefficient. Remove power below fringe-rates of fc0 * bl_len + fc1
# 8 - cache_dir, directory to store cache files in.
fn="${1}"
data_ext="${2}"
label="${3}"
tol="${4}"
frc0="${5}"
frc1="${6}"
cache_dir="${7}"
# get julian day from file name
jd=$(get_jd $fn)
# generate output file name
fn_in=zen.${jd}.sum.${label}.foreground_filtered_waterfall.${data_ext}

if [ -e "${fn_in}" ]
then
  fn_out=zen.${jd}.sum.${label}.xtalk_filtered_waterfall.${data_ext}
  # if cache directory does not exist, make it
  if [ ! -d "${cache_dir}" ]; then
    mkdir ${cache_dir}
  fi

  echo dayenu_xtalk_filter_run.py ${fn_in} \
    --res_outfilename ${fn_out} --clobber \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}   --max_frate_coeffs ${frc0} ${frc1}

  dayenu_xtalk_filter_run.py ${fn_in} \
      --res_outfilename ${fn_out} --clobber \
      --tol ${tol} --cache_dir ${cache_dir} --max_frate_coeffs ${frc0} ${frc1}
else
  echo "${fn_in} does not exist!"
fi
