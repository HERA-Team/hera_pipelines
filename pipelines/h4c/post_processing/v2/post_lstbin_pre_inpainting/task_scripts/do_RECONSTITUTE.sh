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
data_ext="${2}"
label="${3}"
grpstr="${4}"

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`

  sumdiff=("sum" "diff")

  for sd in ${sumdiff[@]}
  do
    # time averaged auto data
    outfilename=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.foreground_filled.tavg.uvh5
    baseline_chunk_files=`echo zen.${grpstr}.LST.${lst}.*.${sd}.${label}.autos.waterfall.tavg.uvh5`
    time_chunk_template=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.foreground_filled.uvh5

    if [ -e "${time_chunk_template}" ]
    then
      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

          time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds
    else
      echo "${time_chunk_template} does not exist!"
    fi
    time_chunk_template=zen.${grpstr}.LST.${lst}.${sd}.${label}.foreground_filled.uvh5
    if [ -e "${time_chunk_template}" ]
    then
      # reconstitute xtalk filtered files
      outfilename=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered_res.uvh5
      baseline_chunk_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered_waterfall.uvh5`
      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber

      time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber
      # cleanup baseline chunks
      #rm -rf ${baseline_chunk_files}

      # time averaged data
      outfilename=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.tavg.uvh5
      baseline_chunk_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered_waterfall.tavg.uvh5`

      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

      time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds
      #rm -rf ${baseline_chunk_files}

      # reconstitute waterfall files.
      outfilename=zen.${grpstr}.LST.${lst}.${sd}.${label}.fg_filtered.uvh5
      baseline_chunk_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.waterfall.uvh5`
      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber

      time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber
      #rm -rf ${baseline_chunk_files}


      # time averaged data
      outfilename=zen.${grpstr}.LST.${lst}.${sd}.${label}.fg_filtered.tavg.uvh5
      baseline_chunk_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.waterfall.tavg.uvh5`


      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

      time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds


      #rm -rf ${baseline_chunk_files}
    else
      echo "${time_chunk_template} does not exist!"
    fi
  done
