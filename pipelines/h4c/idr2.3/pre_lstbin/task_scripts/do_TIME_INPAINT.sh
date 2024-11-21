#! /bin/bash

#-----------------------------------------------------------------------------
# This script performs time inpainting of visibilities using DPSS modes.
# Inpainting is desireable if we want to make fringe-rate heat-maps of our data
# since it eliminates ringing artifacts caused by incomplete time-coverage
# from RFI flags. We do not attempt any LST binning of this data.
#-----------------------------------------------------------------------------


set -e
# sometimes /tmp gets filled up on NRAO nodes hence this line.
# haven't need to use it recently.
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
# 4) tol: determines level to which sky model will be fitted.
# 5) frate_standoff: One of two parameters determining fringe-rate band-width
#    to in-paint over. From https://arxiv.org/abs/1503.05564, we identify the
#    a center fringe rate and fr_hw0; the fringe-rate-half-width predicted to enclose all of the
#    instantaneous fringe-rates on the sky. The half-bandwidth of our inpainting is given by
#    fr_hw = Max(min_frate, fr_hw0 + frate_standoff). frate_standoff has units of [mHz].
# 6) min_frate: One of two parameters determining fringe-rate band-width
#    to in-paint over. From https://arxiv.org/abs/1503.05564, we identify the
#    a center fringe rate and fr_hw0; the fringe-rate-half-width predicted to enclose all of the
#    instantaneous fringe-rates on the sky. The half-bandwidth of our inpainting is given by
#    fr_hw = Max(min_frate, fr_hw0 + frate_standoff). min_frate has units of [mHz].
# 7) spw_ranges: string indicating which channels to keep in output files. Format is
#    comma-separated spectral windows where low/hi channels are joined by a tilde
#    example: "0~10,15~25,30~80" will generate output files with three contiguous
#    spectral windows that include channels 0-10, 15-25, and 30-80 from original
#    files.
# 8) flag_yaml: path to yaml file containing a-priori flags to apply. Can also contain
#               LST ranges that you wish to exclude from the FRF and flag downstream.
#
#
# ASSUMED INPUTS:
# 1) Chunked, calibrated, and foreground in-painted sum / diff files with names of the form
#    zen.<JD>.<sum/diff>.<label>.foreground_filled.uvh5. See do_DELAY.sh
#    for more information (do_DELAY.sh is the prereq task).
#
# OUTPUTS
# 1) sum/diff time-inpainted waterfall files
#    zen.<jd>.<sum/diff>.<label>.foreground_filled.time_inpainted.waterfall.uvh5
#    these files contain a small number of baselines and all time integrations for the night
#    To convert to files with a small number of time integrations and all baselines we must use
#    do_RECONSTITUTE.sh
#
# ------------------------------------------------------------------------------


fn="${1}"
include_diffs="${2}"
label="${3}"
tol="${4}"
frate_standoff="${5}"
min_frate="${6}"
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

for sd in ${sumdiff[@]}
do
    fn_in=zen.${jd}.${sd}.${label}.foreground_filled.uvh5
    fg_files=`echo zen.${int_jd}.*.${sd}.${label}.foreground_filled.uvh5`
    fn_out=zen.${jd}.${sd}.${label}.foreground_filled.time_inpainted.waterfall.uvh5
    #fn_filled=zen.${grpstr}.LST.${lst}.${sd}.${label}.waterfall.uvh5
    if [ -e "${fn_in}" ]
    then
      echo tophat_frfilter_run.py ${fg_files}  --tol ${tol} \
      --min_frate ${min_frate} --frate_standoff ${frate_standoff} --filled_outfilename ${fn_out} \
      --cornerturnfile ${fin_in} --case sky \
      --clobber --verbose --mode dpss_leastsq --filter_spw_ranges ${spw_ranges} --flag_yaml ${flag_yaml}

      tophat_frfilter_run.py ${fg_files}  --tol ${tol} \
      --min_frate ${min_frate} --frate_standoff ${frate_standoff} --filled_outfilename ${fn_out} \
      --cornerturnfile ${fn_in} --case sky \
      --clobber --verbose --mode dpss_leastsq --filter_spw_ranges ${spw_ranges} --flag_yaml ${flag_yaml}
    else
      echo "${fn_in} does not exist!"
    fi
  done
