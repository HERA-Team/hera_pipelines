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
frate_standoff="${7}"
cache_dir="${8}"
# get julian day from file name
jd=$(get_jd $fn)
int_jd=${jd:0:7}
# generate output file name

# if cache directory does not exist, make it
parities=("0" "1")
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  for parity in ${parities[@]}
  do
    data_extp=${data_ext/.uvh5/.${parity}.uvh5}
    fn_in=zen.${jd}.${sd}.${label}.foreground_filled.${data_extp}
    fg_files=`echo zen.${int_jd}.*.${sd}.${label}.foreground_filled.${data_extp}`
    fn_res=zen.${jd}.${sd}.${label}.xtalk_filtered_waterfall.${data_extp}
    fn_filled=zen.${jd}.${sd}.${label}.waterfall.${data_extp}
    if [ -e "${fn_in}" ]
    then
      echo dpss_xtalk_filter_run_baseline_parallelized.py ${fn_in} --tol ${tol} \
      --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_res} \
      --filled_outfilename ${fn_filled} --inpaint --frate_standoff ${frate_standoff} \
      --clobber --datafilelist ${fg_files} --skip_flagged_edges --verbose

      dpss_xtalk_filter_run_baseline_parallelized.py ${fn_in} --tol ${tol} \
      --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_res} \
      --filled_outfilename ${fn_filled} --inpaint --frate_standoff ${frate_standoff} \
      --clobber --datafilelist ${fg_files} --skip_flagged_edges --verbose
    else
      echo "${fn_in} does not exist!"
    fi
  done
done
