#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"
chunk_size="${3}"

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`


jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
fi


sumdiff=("sum" "diff")
exts=("foreground_filled" "foreground_res.filled_flags" "foreground_model.filled_flags")

for sd in ${sumdiff[@]}
do
  for ext in ${exts[@]}
  do
    # chunk full baseline files.
    input_file=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.uvh5
    input_files=`echo zen.${int_jd}.*.${sd}.${label}.${ext}.xtalk_filtered.uvh5`
    output_file=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.chunked.uvh5
    echo chunk_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
    --clobber
    chunk_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
    --clobber
  done
done
