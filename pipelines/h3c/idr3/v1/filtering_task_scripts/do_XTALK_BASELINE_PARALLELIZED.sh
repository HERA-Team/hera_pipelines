#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - file name
# 2 - data extension
# 3 - output label
# 4 - Level to subtract cross-talk too.
# 5 - First xtalk filter coefficient. Remove power below fringe-rates of fc0 * bl_len + fc1.
# 6 - Second xtalk filter coefficient. Remove power below fringe-rates of fc0 * bl_len + fc1
# 7 - Cache Directory.

fn="${1}"
data_ext="${2}"
label="${3}"
tol="${4}"
frc0="${5}"
frc1="${6}"
cache_dir="${7}"
# get julian day from file name
jd=$(get_jd $fn)
int_jd=${jd:0:7}
# generate output file name
fn_in=${fn%.uvh5}.${label}.foreground_filtered.${data_ext}
fn_out=${fn%.uvh5}.${label}.xtalk_filtered_waterfall.${data_ext}
# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi
# list of all foreground filtered files.
# this will be broken by diff files.
# had to hard code sum annoyingly.
data_files=`echo zen.${int_jd}.*.sum.${label}.foreground_filtered.${data_ext}`


echo dayenu_xtalk_filter_run_baseline_parallelized.py ${fn_in} --tol ${tol} \
 --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_out} \
 --clobber --datafilelist ${data_files} --skip_flagged_edges


 dayenu_xtalk_filter_run_baseline_parallelized.py ${fn_in} --tol ${tol} \
  --max_frate_coeffs ${frc0} ${frc1}  --res_outfilename ${fn_out} \
  --clobber --datafilelist ${data_files} --skip_flagged_edges
