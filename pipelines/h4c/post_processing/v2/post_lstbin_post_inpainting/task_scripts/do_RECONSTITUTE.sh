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
grpstr="${4}"

lst=`echo ${fn} | sed -r 's/^.*LST.//' | sed -r 's/.sum.*//'`



  parities=("0" "1")
  sumdiff=("sum" "diff")

  for sd in ${sumdiff[@]}
  do
    # first reconstitute waterfall xtalk res files produced if we are running inpainting post lstbin.
    outfilename=zen.${grpstr}.LST.${lst}.${sd}.${label}.auto.foreground_filled.tavg.uvh5
    baseline_chunk_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.auto.foreground_filled.waterfall.tavg.uvh5`
    time_chunk_template=zen.${grpstr}.LST.${lst}.${sd}.${label}.auto.foreground_filled.uvh5
    # this code should only execute if we are doing filtering post lstbinning.
    if [ -e "${time_chunk_template}" ]
    then
      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

          time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds
    else
      echo "${time_chunk_template} does not exist!"
    fi
    for parity in ${parities[@]}
    do
      data_extp=${data_ext/.uvh5/.${parity}.uvh5}
      time_chunk_template=zen.${grpstr}.LST.${lst}.${sd}.${label}.foreground_filled.${data_extp}
      if [ -e "${time_chunk_template}" ]
      then
        # reconstitute xtalk filtered files
        outfilename=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.${data_extp}
        baseline_chunk_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered.waterfall.${data_extp}`
        echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber

        time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber
        # cleanup baseline chunks
        #rm -rf ${baseline_chunk_files}
      else
        echo "${time_chunk_template} does not exist!"
      fi
      time_chunk_template=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.${data_extp}
      # time averaged data
      outfilename=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.tavg.${data_extp}
      baseline_chunk_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered.waterfall.tavg.${data_extp}`

      echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

      time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
          --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

      # this code should only execute if we are doing filtering post lstbinning.
      time_chunk_template=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_inpainted.${data_extp}
      if [ -e "${time_chunk_template}" ]
      then
        # time averaged data
        outfilename=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_inpainted.tavg.${data_extp}
        baseline_chunk_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_inpainted.waterfall.tavg.${data_extp}`


        echo time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds

        time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --outfilename ${outfilename}\
            --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds
        #rm -rf ${baseline_chunk_files}
      else
        echo "${time_chunk_template} does not exist!"
      fi
  done
done
