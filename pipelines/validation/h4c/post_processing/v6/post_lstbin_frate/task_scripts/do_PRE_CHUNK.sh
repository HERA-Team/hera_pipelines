#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
include_diffs="${2}"
label="${3}"
chunk_size="${4}"

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`


jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
  int_jd="LST"
fi



if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi



exts=( "foreground_filled.xtalk_filtered")

for sd in ${sumdiff[@]}
do
  for ext in ${exts[@]}
  do
    # chunk full baseline files.
    input_file=zen.${jd}.${sd}.${label}.${ext}.uvh5
    input_files=`echo zen.${int_jd}.*.${sd}.${label}.${ext}.uvh5`
    output_file=zen.${jd}.${sd}.${label}.${ext}.chunked.uvh5
    echo chunk_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
    --clobber
    chunk_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
    --clobber
  done
done
