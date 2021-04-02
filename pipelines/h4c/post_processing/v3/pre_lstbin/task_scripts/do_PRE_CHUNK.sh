#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"
chunk_size="${3}"
spw0="${4}"
spw1="${5}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}



sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # chunk auto files.
  input_auto=zen.${jd}.${sd}.autos.uvh5
  output_auto=zen.${jd}.${sd}.${label}.autos.chunked.uvh5
  autofiles=`echo zen.${int_jd}.*.${sd}.autos.uvh5`
  echo chunk_data_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn
  chunk_data_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn
  # stage full baseline files.
  input_files=""
  # iterate over files until we reach the specific jd
  visited_fname="false"
  counter=0
  for filename in zen.${int_jd}.*.${sd}.autos.uvh5
  do
    jd_temp=$(get_jd $filename)
    if [ "${jd_temp}" = "${jd}" ]
    then
      visited_fname="true"
    fi
    # If we visited the input filename and the counter is less then chunk size.
    if [ "${visited_fname}" = "true" ] and [ "${counter}" -lt "${chunk_size}" ]
    then
      # stage data for the JD.
      json_string='{"name-matches": "zen.'"${jd_temp}.${sd}"'.uvh5"}'
      echo librarian stage-files -w local `pwd`  "$json_string"
      librarian stage-files -w local `pwd` "$json_string"
      # concatenate name of staged file to list of files to be fed to file chunker.
      input_files=${input_files}" zen.${jd_temp}.${sd}.uvh5"
      # update counter
      counter=$((${counter} + 1))
    fi
  done
  # chunk staged input baseline files into a single file.
  input_file=zen.${jd}.${sd}.uvh5
  output_file=zen.${jd}.${sd}.${label}.chunked.uvh5
  echo chunk_data_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
  --clobber --polarizations ee nn --spw_range ${spw0} ${spw1}
  chunk_data_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
  --clobber --polarizations ee nn --spw_range ${spw0} ${spw1}
  # remove original files after chunking
  echo rm -rf ${input_files}
  rm -rf ${input_files}
done
