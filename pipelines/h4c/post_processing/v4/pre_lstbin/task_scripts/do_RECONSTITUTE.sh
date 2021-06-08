#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# This script reconstitutes as time chunk from many baselines.
# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - template file name (template for time chunk to reconstitute).
# 2 - data extension
# 2 - output label for identifying file.

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
exts=("foreground_filled" "foreground_res" "foreground_model")
for sd in ${sumdiff[@]}
do
  time_chunk_template=zen.${jd}.${sd}.${label}.foreground_filled.uvh5
  if [ -e "${time_chunk_template}" ]
  then
    for ext in ${exts[@]}
    do
      # reconstitute xtalk filtered files
      outfilename=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.uvh5
      baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.${ext}.xtalk_filtered.waterfall.uvh5`
      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber
      time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber

      if [ "${ext}" = "foreground_model" ]
      then
        # transfer flags from res file to model file.
        echo transfer_flags.py zen.${jd}.${sd}.${label}.foreground_res.xtalk_filtered.uvh5 ${outfilename} ${outfilename} --clobber
        transfer_flags.py zen.${jd}.${sd}.${label}.foreground_res.xtalk_filtered.uvh5 ${outfilename} ${outfilename} --clobber
      fi
    done
    # reconstitute fr inpainted files

    outfilename=zen.${jd}.${sd}.${label}.foreground_filled.time_inpainted.uvh5
    baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.foreground_filled.time_inpainted.waterfall.uvh5`

    echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber

    time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber


    # reconstitute xtalk filtered time-averaged files (only do foreround_filled xtalk filtered files).
    outfilename=zen.${jd}.${sd}.${label}.foreground_filled.xtalk_filtered.tavg.uvh5
    baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.foreground_filled.xtalk_filtered.waterfall.tavg.uvh5`

    echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

    time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

    # reconstitute fr-inpainted time-averaged files
    outfilename=zen.${jd}.${sd}.${label}.foreground_filled.time_inpainted.tavg.uvh5
    baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.foreground_filled.time_inpainted.waterfall.tavg.uvh5`

    echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

    time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

  else
    echo "${time_chunk_template} does not exist!"
  fi
done
