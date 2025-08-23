#! /bin/bash

#-----------------------------------------------------------------------------
# This script performs frequency domain in-painting with either DPSS modes or
# the CLEAN algorithm.
# ----------------------------------------------------------------------------

set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# ------------------------------------------------------------------------------
# ARGUMENTS
# 1) Inpute filename (string). Assumed to contain JD.
# 2) Whether or not to perform analysis on diff files as well as sum files.
#    valid options are "true" or "false".
# 3) identifying string label for analysis outputs to set it apart from other
#    runs with different parameters.
# 4) Level of foreground residual to leave in the data
#    (or halting condition for CLEAN`)
# 5) standoff parameter for determining extent of delay inpainting. Units of ns.
#    Max inpaint delay is given by tau = Max(bl_len / speed of light + standoff,
#    min_dly)
# 6) min_dly parameter for determining extent of delay inpainting. Units of ns.
#    Max inpaint delay is given by tau = Max(bl_len / speed of light + standoff,
#    min_dly)
# 7) cache_dir: path to cache directory containing compressed filter file archives
# 8) filter_mode: string indicating whether to use CLEAN or "DPSS" for
#    dpss_leastsq inpaint.
# 9) nbl_per_load: number of baselines to load and inpaint simultaneously.
# 10) spw_ranges: string indicating which channels to keep in output files. Format is
#    comma-separated spectral windows where low/hi channels are joined by a tilde
#    example: "0~10,15~25,30~80" will generate output files with three contiguous
#    spectral windows that include channels 0-10, 15-25, and 30-80 from original
#    files.
# 11) flag_yaml: path to yaml file containing a-priori flags to apply.
#
# ASSUMED INPUTS:
# 1) Chunked and calibrated sum / diff files with names of the form
#    zen.<JD>.<sum/diff>.<label>.chunked.uvh5. See do_PRE_CHUNK_NO_GAIN_FIX.sh
#
# OUTPUTS
# 1) sum/diff model files with the fitted smooth components
#    of foreground model with nameing convention
#    zen.<jd>.<sum/diff>.<label>.foreground_model.uvh5
# 2) sum/diff delay-inpainted files with naming convention
#    zen.${jd}.${sd}.${label}.foreground_filled.uvh5
# 3) sum/diff fn_res=zen.${jd}.${sd}.${label}.foreground_res.uvh5
#    files where the smooth foreground components have been subtracted.
# ------------------------------------------------------------------------------

fn="${1}"
include_diffs="${2}"
label="${3}"
tol="${4}"
standoff="${5}"
min_dly="${6}"
cache_dir="${7}"
filter_mode="${8}"
nbl_per_load="${9}"
spw_ranges="${10}"
flag_yaml="${11}"

# get julian day from file name
jd=$(get_jd $fn)
int_jd=${jd:0:7}

# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi

# determine whether we are also processing diff files.
if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi

for sd in ${sumdiff[@]}
do
    fn_in=zen.${jd}.${sd}.${label}.chunked.uvh5
    fn_out=zen.${jd}.${sd}.${label}.foreground_filled.uvh5
    fn_cln=zen.${jd}.${sd}.${label}.foreground_model.uvh5
    fn_res=zen.${jd}.${sd}.${label}.foreground_res.uvh5
    if [ -e "${fn_in}" ]
    then
      if [ "${filter_mode}" == "DPSS" ]
      then
        # Command for DPSS inpainting
        echo delay_filter_run.py ${fn_in}  \
          --filled_outfilename ${fn_out} --clobber --apply_flag_to_nsample\
          --res_outfilename ${fn_res} --CLEAN_outfilename ${fn_cln}  \
          --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}  \
          --min_dly ${min_dly}  --mode dpss_leastsq --filter_spw_ranges ${spw_ranges} --flag_yaml ${flag_yaml}
        delay_filter_run.py ${fn_in}  \
          --filled_outfilename ${fn_out} --clobber  --apply_flag_to_nsample\
          --res_outfilename ${fn_res} --CLEAN_outfilename ${fn_cln}  \
          --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}  \
          --min_dly ${min_dly}  --mode dpss_leastsq --filter_spw_ranges ${spw_ranges} --flag_yaml ${flag_yaml}
      elif [ "${filter_mode}" == "CLEAN" ]
      then
        # Command for CLEAN inpainting
        npad=$((${spw1}-${spw0}))
        echo delay_filter_run.py ${fn_in}  \
        --filled_outfilename ${fn_out} --clobber --apply_flag_to_nsample\
        --res_outfilename ${fn_res} --CLEAN_outfilename ${fn_cln}  \
        --tol ${tol} --standoff ${standoff}   --filter_spw_ranges ${spw_ranges}\
        --min_dly ${min_dly} --edgecut_low ${npad} --edgecut_hi ${npad} --zeropad ${npad} --mode clean --flag_yaml ${flag_yaml}

        delay_filter_run.py ${fn_in} \
        --filled_outfilename ${fn_out} --clobber --apply_flag_to_nsample\
        --res_outfilename ${fn_res} --CLEAN_outfilename ${fn_cln}  \
        --tol ${tol} --standoff ${standoff}   --filter_spw_ranges ${spw_ranges}\
        --min_dly ${min_dly} --edgecut_low ${npad} --edgecut_hi ${npad} --zeropad ${npad} --mode clean --flag_yaml ${flag_yaml}
      fi
    else
      echo "${fn_in} does not exist!"
    fi
  done
