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
fn_in_even=zen.${jd}.even.${label}.foreground_filtered_res.${data_ext}
fn_in_odd=${fn_in_even/even/odd}
fn_res_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_res.${data_ext}
fn_res_odd=${fn_res_even/even/odd}
fn_filled_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_filled.${data_ext}
fn_filled_odd=${fn_filled_even/even/odd}




# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi
# list of all foreground filtered files.
# this will be broken by diff files.
# had to hard code sum annoyingly.
data_files_even=`echo zen.${int_jd}.*.even.${label}.foreground_filtered_res.${data_ext}`
data_files_odd=`echo zen.${int_jd}.*.odd.${label}.foreground_filtered_res.${data_ext}`


echo dpss_xtalk_filter_run_baseline_parallelized.py ${fn_in_even} --tol ${tol} \
 --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_res_even} \
 --filled_outfilename ${fn_filled_even} \
 --clobber --datafilelist ${data_files_even} --skip_flagged_edges

 dpss_xtalk_filter_run_baseline_parallelized.py ${fn_in_even} --tol ${tol} \
  --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_res_even} \
  --filled_outfilename ${fn_filled_even} \
  --clobber --datafilelist ${data_files_even} --skip_flagged_edges

 echo dpss_xtalk_filter_run_baseline_parallelized.py ${fn_in_odd} --tol ${tol} \
  --max_frate_coeffs ${frc0} ${frc1}  --res_outfilename ${fn_res_odd} \
  --filled_outfilename ${fn_filled_odd} \
  --clobber --datafilelist ${data_files_odd} --skip_flagged_edges

 dpss_xtalk_filter_run_baseline_parallelized.py ${fn_in_odd} --tol ${tol} \
  --max_frate_coeffs ${frc0} ${frc1}  --res_outfilename ${fn_res_odd} \
  --filled_outfilename ${fn_filled_odd} \
  --clobber --datafilelist ${data_files_odd} --skip_flagged_edges
