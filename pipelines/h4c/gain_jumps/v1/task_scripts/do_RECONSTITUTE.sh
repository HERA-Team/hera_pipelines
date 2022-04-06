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
label="${2}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

sd="sum"

time_chunk_template=zen.${jd}.${sd}.${label}.red_avg.chunked.foreground_model.uvh5
if [ -e "${time_chunk_template}" ]
then
  # reconstitute xtalk filtered files
  outfilename=zen.${jd}.${sd}.${label}.red_avg.chunked.foreground_model.time_inpainted.uvh5
  baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.red_avg.chunked.foreground_model.time_inpainted.waterfall.uvh5`
  echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
      --baseline_chunk_files ${baseline_chunk_files} --clobber
  time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
      --baseline_chunk_files ${baseline_chunk_files} --clobber
else
  echo "${time_chunk_template} does not exist!"
fi
