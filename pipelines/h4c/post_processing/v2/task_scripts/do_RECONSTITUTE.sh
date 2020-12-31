#! /bin/bash
set -e

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

jd=$(get_jd $fn)
int_jd=${jd:0:7}


  parities=("0" "1")
  sumdiff=("sum" "diff")

  for sd in ${sumdiff[@]}
  do
    for parity in ${parities[@]}
    do
      data_extp=${data_ext/.uvh5/.${parity}.uvh5}
      time_chunk_template=zen.${jd}.${sd}.${label}.foreground_filled.${data_extp}
      if [ -e "${time_chunk_template}" ]
      then
        # reconstitute xtalk filtered files
        outfilename=zen.${jd}.${sd}.${label}.xtalk_filtered_res.${data_extp}
        baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.xtalk_filtered_waterfall.${data_extp}`
        echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber

        time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber

        # time averaged data
        outfilename=zen.${jd}.${sd}.${label}.xtalk_filtered.tavg.${data_extp}
        baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.xtalk_filtered_waterfall.tavg.${data_extp}`

        echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

        time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

        # reconstitute waterfall files.
        outfilename=zen.${jd}.${sd}.${label}.fg_filtered.${data_extp}
        baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.waterfall.${data_extp}`
        echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber

        time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber


        # time averaged data
        outfilename=zen.${jd}.${sd}.${label}.fg_filtered.tavg.${data_extp}
        baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.waterfall.tavg.${data_extp}`


        echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

        time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds
      else
        echo "${time_chunk_template} does not exist!"
      fi
  done
done
