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
grpstr="${6}"

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`




sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # chunk auto files.
  input_auto=zen.${grpstr}.LST.${lst}.${sd}.autos.uvh5
  output_auto=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.chunked.uvh5
  autofiles=`echo zen.${grpstr}.LST.*.${sd}.autos.uvh5`
  echo chunk_data_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn
  chunk_data_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn
  # chunk full baseline files.
  input_file=zen.${grpstr}.LST.${lst}.${sd}.uvh5
  input_files=`echo zen.${grpstr}.LST.*.${sd}.uvh5`
  output_file=zen.${grpstr}.LST.${lst}.${sd}.${label}.chunked.uvh5
  echo chunk_data_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
  --clobber --polarizations ee nn --spw_range ${spw0} ${spw1}
  chunk_data_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
  --clobber --polarizations ee nn --spw_range ${spw0} ${spw1}
done
