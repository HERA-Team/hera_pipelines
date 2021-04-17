#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"
chunk_size="${3}"
grpstr="${4}"

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`




sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # chunk auto files.
  input_auto=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.foreground_filled.uvh5
  output_auto=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.foreground_filled.chunked.uvh5
  autofiles=`echo zen.${grpstr}.LST.*.${sd}.${label}.autos.foreground_filled.uvh5`
  echo chunk_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
    --clobber
  chunk_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
    --clobber
  # chunk full baseline files.
  input_file=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered_res.uvh5
  input_files=`echo zen.${grpstr}.LST.*.${sd}.${label}.xtalk_filtered_res.uvh5`
  output_file=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.chunked.uvh5
  echo chunk_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
  --clobber
  chunk_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
  --clobber
done
