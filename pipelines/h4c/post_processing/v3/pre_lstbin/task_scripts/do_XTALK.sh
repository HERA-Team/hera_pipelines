#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

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
label="${2}"
tol="${3}"
frc0="${4}"
frc1="${5}"
frate_standoff="${6}"
cache_dir="${7}"


jd=$(get_jd $fn)
int_jd=${jd:0:7}

# if cache directory does not exist, make it
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
    fn_in=zen.${jd}.${sd}.${label}.foreground_filled.uvh5
    fg_files=`echo zen.${int_jd}.*.${sd}.${label}.foreground_filled.uvh5`
    fn_res=zen.${jd}.${sd}.${label}.xtalk_filtered_waterfall.uvh5
    #fn_filled=zen.${grpstr}.LST.${lst}.${sd}.${label}.waterfall.uvh5
    if [ -e "${fn_in}" ]
    then
      echo dpss_xtalk_filter_run_baseline_parallelized.py ${fn_in} --tol ${tol} \
      --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_res} \
      --frate_standoff ${frate_standoff} \
      --clobber --datafilelist ${fg_files} --skip_flagged_edges --verbose --skip_autos

      dpss_xtalk_filter_run_baseline_parallelized.py ${fn_in} --tol ${tol} \
      --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_res} \
      --frate_standoff ${frate_standoff} \
      --clobber --datafilelist ${fg_files} --skip_flagged_edges --verbose --skip_autos
    else
      echo "${fn_in} does not exist!"
    fi
  done
