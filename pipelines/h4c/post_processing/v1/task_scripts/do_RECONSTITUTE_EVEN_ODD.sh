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

time_chunk_template=${fn%.uvh5}.${label}.chunked.${data_ext}
jd=$(get_jd $time_chunk_template)
int_jd=${jd:0:7}

if [ -e "${time_chunk_template}" ]
then
  parities=("even" "odd")
  for parity in ${parities[@]}
  do
    # reconstitute xtalk filtered files with no foregrounds
    outfilename=zen.${jd}.${parity}.${label}.xtalk_filtered_res.${data_ext}
    baseline_chunk_files=`echo zen.${int_jd}.*.${parity}.${label}.xtalk_filtered_waterfall_res.${data_ext}`
    tfile=zen.${jd}.${parity}.${label}.xtalk_filtered_waterfall_res.${data_ext}
    if [ -e "${tfile}" ]
    then
      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber

      time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber
    else
      echo "noforeground files were not produced."
    fi

    outfilename=zen.${jd}.${parity}.${label}.xtalk_filtered_withforegrounds.${data_ext}
    baseline_chunk_files=`echo zen.${int_jd}.*.${parity}.${label}.xtalk_filtered_waterfall_withforegrounds.${data_ext}`


    echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber

    time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber

    # time averaged data
    outfilename=zen.${jd}.${parity}.${label}.xtalk_filtered_withforegrounds.tavg.${data_ext}
    baseline_chunk_files=`echo zen.${int_jd}.*.${parity}.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.${data_ext}`

    echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

    time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds


    # reconstitute xtalk filtered files with foregrounds but low fringe-rates filled in.
    outfilename=zen.${jd}.even.${label}.withforegrounds.${data_ext}
    baseline_chunk_files=`echo zen.${int_jd}.*.even.${label}.waterfall_withforegrounds.${data_ext}`


    echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber

    time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber


    # time averaged data
    outfilename=zen.${jd}.even.${label}.withforegrounds.tavg.${data_ext}
    baseline_chunk_files=`echo zen.${int_jd}.*.even.${label}.waterfall_withforegrounds.tavg.${data_ext}`


    echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

    time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
        --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

  done

else
  echo "${time_chunk_template} does not exist!"
fi
