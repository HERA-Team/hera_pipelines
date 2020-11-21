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
# 8 - if true, do no foregrounds file. This could run substantially slower if flags are not separable.

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

# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi
parities=("even" "odd")
for parity in ${parities[@]}
do
  fn_res=zen.${jd}.${parity}.${label}.foreground_res.${data_ext} #foreground residual
  resid_files=`echo zen.${int_jd}.*.${parity}.${label}.foreground_res.${data_ext}`
  fn_model=zen.${jd}.${parity}.${label}.foreground_model.${data_ext} #foreground model
  foreground_files=`echo zen.${int_jd}.*.${parity}.${label}.foreground_model.${data_ext}`

  fn_CLEAN_xtalk=zen.${jd}.${parity}.${label}.waterfall_foregrounds.${data_ext}
  fn_resid_xtalk=zen.${jd}.${parity}.${label}.waterfall_res.${data_ext}

  fn_xtalk=zen.${jd}.${parity}.${label}.waterfall_withforegrounds.${data_ext}
  fn_CLEAN_noxtalk=zen.${jd}.${parity}.${label}.xtalk_filtered_waterfall_foregrounds.${data_ext}
  fn_resid_noxtalk=zen.${jd}.${parity}.${label}.xtalk_filtered_waterfall_res.${data_ext}
  fn_noxtalk=zen.${jd}.${parity}.${label}.xtalk_filtered_waterfall_withforegrounds.${data_ext}

  if [ -e "${fn_model}" ]
  then
    echo dpss_xtalk_filter_run_baseline_parallelized.py ${fn_res} --tol ${tol} \
    --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_resid_noxtalk} \
    --filled_outfilename ${fn_resid_xtalk} \
    --clobber --datafilelist ${resid_files} --skip_flagged_edges --verbose

    dpss_xtalk_filter_run_baseline_parallelized.py ${fn_res} --tol ${tol} \
    --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_resid_noxtalk} \
    --filled_outfilename ${fn_resid_xtalk} \
    --clobber --datafilelist ${resid_files} --skip_flagged_edges --verbose

    echo dpss_xtalk_filter_run_baseline_parallelized.py ${fn_model} --tol ${tol} \
     --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_CLEAN_noxtalk} \
     --CLEAN_outfilename ${fn_CLEAN_xtalk} \
     --clobber --datafilelist ${foreground_files} --skip_flagged_edges --verbose

     dpss_xtalk_filter_run_baseline_parallelized.py ${fn_model} --tol ${tol} \
      --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_CLEAN_noxtalk} \
      --CLEAN_outfilename ${fn_CLEAN_xtalk} \
      --clobber --datafilelist ${foreground_files} --skip_flagged_edges --verbose

    if [ -e "${fn_CLEAN_xtalk}" ]
    then
      echo sum_files.py ${fn_CLEAN_noxtalk} ${fn_resid_noxtalk} ${fn_noxtalk} --clobber
      sum_files.py ${fn_CLEAN_noxtalk} ${fn_resid_noxtalk} ${fn_noxtalk} --clobber

      echo sum_files.py ${fn_CLEAN_xtalk} ${fn_resid_xtalk} ${fn_xtalk} --clobber
      sum_files.py ${fn_CLEAN_xtalk} ${fn_resid_xtalk} ${fn_xtalk} --clobber
    fi
  else
    echo "${fn_model} does not exist!"
  fi
done
