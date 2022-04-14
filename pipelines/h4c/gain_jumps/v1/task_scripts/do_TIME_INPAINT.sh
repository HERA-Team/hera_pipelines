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
frate_standoff="${4}"
min_frate="${5}"
cache_dir="${6}"
spw_ranges="${7}"


jd=$(get_jd $fn)
int_jd=${jd:0:7}

sumdiff=("sum")

for sd in ${sumdiff[@]}
do
    fn_in=zen.${jd}.${sd}.${label}.red_avg.chunked.foreground_model.uvh5
    #fg_files=`echo zen.${int_jd}.*.${sd}.${label}.red_avg.chunked.foreground_model.uvh5`
    fg_files=`echo zen.${int_jd}.*.${sd}.${label}.chunked.foreground_model.uvh5`
    fn_out=zen.${jd}.${sd}.${label}.chunked.foreground_model.time_inpainted.waterfall.uvh5
    #fn_out=zen.${jd}.${sd}.${label}.red_avg.chunked.foreground_model.time_inpainted.waterfall.uvh5
    #fn_filled=zen.${grpstr}.LST.${lst}.${sd}.${label}.waterfall.uvh5
    if [ -e "${fn_in}" ]
    then
      echo tophat_frfilter_run.py ${fg_files}  --tol ${tol} --clean_flags_in_resid_flags \
      --min_frate_half_width ${min_frate} --frate_standoff ${frate_standoff} --CLEAN_outfilename ${fn_out} \
      --cornerturnfile ${fn_in} \
      --clobber --verbose --mode dpss_leastsq --filter_spw_ranges ${spw_ranges}

      tophat_frfilter_run.py ${fg_files}  --tol ${tol} --clean_flags_in_resid_flags \
      --min_frate_half_width ${min_frate} --frate_standoff ${frate_standoff} --CLEAN_outfilename ${fn_out} \
      --cornerturnfile ${fn_in} \
      --clobber --verbose --mode dpss_leastsq --filter_spw_ranges ${spw_ranges}
    else
      echo "${fn_in} does not exist!"
    fi
  done
