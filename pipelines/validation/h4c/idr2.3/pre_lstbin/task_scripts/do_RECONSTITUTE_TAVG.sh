#! /bin/bash
#-----------------------------------------------------------------------------
# This script reverses the corner-turn performed by the cross-talk subtraction
# and time-inpainting scripts for time-averaged files.
# do_XTALK.sh and do_TIME_INTPAINT.sh both produce
# waterfall files where each file contains a small number of baselines and all
# LSTs on that night. do_TIME_AVERAGE.sh produces time-averaged versions of these
# waterfall files. Downstream tomls, on the other hand, assume files that contain
# all baselines for the night in each file and a small number of times. The naming
# convention that we use also implies that files contain observations close to a
# specific JD or LST. Efficient parallelization of the power spectrum code also
# requires that each time chunk knows about all LSTs
# ASIDE: although in the future
# we might consider paralellizing power spectrum estimation across redundant groups
# and forego the notion of fields altogether.
# this will almost certainly require time in-painting and keeping track of the statistics
# of estimates of the fringe-rate modes.
#-----------------------------------------------------------------------------

set -e
# sometimes /tmp gets filled up on NRAO nodes hence this line.
# haven't need to use it recently.
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

#-----------------------------------------------------------------------------
# ARGUMENTS:
# 1) fn: Input filename (string) assumed to contain JD.
# 2) include_diffs: Whether or not to perform analysis on diff files as well as sum files.
#    valid options are "true" or "false".
# 3) label: identifying string label for analysis outputs to set it apart from other
#    runs with different parameters.
#
#
# ASSUMED INPUTS:
# 1) Chunked, calibrated, foreground in-painted, xtalk_filtered/time_inpainted (optional)
#    sum / diff waterfall, time-avergaged files where each files has all time integrations on the night
#    and together all of the files contain all baselines from the night. These files have names of the form
#    * zen.<JD>.<sum/diff>.<label>.foreground_filled.xtalk_filtered.waterfall.tavg.uvh5 (xtalk_filtered waterfalls)
#    * zen.<JD>.<sum/diff>.<label>.foreground_filled.time_inpainted.waterfall.tavg.uvh5 (time_inpainted waterfalls [optional])
#    If time_inpainted waterfalls are not present in the run dir, they are simply not processed.
#
# OUTPUTS:
# 1) sum/diff time_inpainted and xtalk_filtered and time-averaged files with cornerturn reversed.
#    Names have the format
#    * zen.<JD>.<sum/diff>.<label>.foreground_filled.xtalk_filtered.tavg.uvh5 (xtalk_filtered)
#    * zen.<JD>.<sum/diff>.<label>.foreground_filled.time_inpainted.tavg.uvh5 (time_inpainted)
#
#-----------------------------------------------------------------------------


fn="${1}"
include_diffs="${2}"
label="${3}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}


if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi
exts=("foreground_filled")
for sd in ${sumdiff[@]}
do
  time_chunk_template=zen.${jd}.${sd}.${label}.foreground_filled.xtalk_filtered.uvh5
  if [ -e "${time_chunk_template}" ]
  then
    for ext in ${exts[@]}
    do
      # reconstitute xtalk filtered files
      outfilename=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.tavg.uvh5
      baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.${ext}.xtalk_filtered.waterfall.tavg.uvh5`
      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds
      time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds
    done
      nchunks=`ls zen.${int_jd}.*.${sd}.${label}.foreground_filled.time_inpainted.waterfall.uvh5 | wc -l`
      # check that time inpainted files exist.
      if [ "${nchunks}" != "0" ]
      then
        # reconstitute fr-inpainted time-averaged files
        outfilename=zen.${jd}.${sd}.${label}.foreground_filled.time_inpainted.tavg.uvh5
        baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.foreground_filled.time_inpainted.waterfall.tavg.uvh5`

        echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

        time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds
      fi
  else
    echo "${time_chunk_template} does not exist!"
  fi
done
