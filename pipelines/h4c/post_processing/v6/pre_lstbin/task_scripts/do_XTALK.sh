#! /bin/bash

#-----------------------------------------------------------------------------
# This script performs subtraction of slow fringe-rate cross-talk structure
# similar to what was found in the H1C IDR2.2 results but instead of using
# SVD, we fit and subtract DPSS modes.
# In order to process all observation times on a night within each job
# it performs a "corner-turn" where we transform from files with a small
# number of time integrations and all baselines to files with a small number
# of baselines and all integratins in a night.
# see do_RECONSTITUTE.sh to undo the cornerturn and transform back into files
# with all baselines and small number of integrations.
#-----------------------------------------------------------------------------


set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/
#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

#-----------------------------------------------------------------------------
# ARGUMENTS
# 1) fn: Input filename (string) assumed to contain JD.
# 2) include_diffs: Whether or not to perform analysis on diff files as well as sum files.
#    valid options are "true" or "false".
# 3) label: identifying string label for analysis outputs to set it apart from other
#    runs with different parameters.
# 4) tol: 


# 1 - file name
# 2 - data extension
# 3 - output label
# 4 - Level to subtract cross-talk too.
# 5 - First xtalk filter coefficient. Remove power below fringe-rates of fc0 * bl_len + fc1.
# 6 - Second xtalk filter coefficient. Remove power below fringe-rates of fc0 * bl_len + fc1
# 7 - Cache Directory.
# 8 - if true, do no foregrounds file. This could run substantially slower if flags are not separable.

fn="${1}"
include_diffs="${2}"
label="${3}"
tol="${4}"
frc0="${5}"
frc1="${6}"
cache_dir="${7}"
spw_ranges="${8}"
flag_yaml="${9}"


jd=$(get_jd $fn)
int_jd=${jd:0:7}

# if cache directory does not exist, make it
if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi
exts=("foreground_filled")
for sd in ${sumdiff[@]}
do
    # do res files, model files, and filled files.
    for ext in ${exts[@]}
    do
      fn_in=zen.${jd}.${sd}.${label}.${ext}.uvh5
      fg_files=`echo zen.${int_jd}.*.${sd}.${label}.${ext}.uvh5`
      fn_res=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.waterfall.uvh5
      if [ -e "${fn_in}" ]
      then
        echo tophat_frfilter_run.py ${fg_files}  --tol ${tol}  \
        --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_res} \
        --cornerturnfile ${fn_in} --case max_frate_coeffs \
        --clobber --verbose --mode dpss_leastsq --skip_autos --filter_spw_ranges ${spw_ranges} --flag_yaml ${flag_yaml}

        tophat_frfilter_run.py ${fg_files}  --tol ${tol}  \
        --max_frate_coeffs ${frc0} ${frc1} --res_outfilename ${fn_res} \
        --cornerturnfile ${fn_in} --case max_frate_coeffs \
        --clobber --verbose --mode dpss_leastsq --skip_autos --filter_spw_ranges ${spw_ranges} --flag_yaml ${flag_yaml}
      else
        echo "${fn_in} does not exist!"
      fi
    done
    # cross-talk filter the model files.
    # cross-talke filter the
  done
