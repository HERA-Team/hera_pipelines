#!/bin/bash
set -e
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

horizon="${1}"
offset="${2}"
min_dly="${3}"
bllen_min="${4}"
bllen_max="${5}"
bl_ew_min="${6}"
ex_ants="${7}"
data_files="${@:8}"

ex_ants="${ex_ants//,/$' '}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
fi

fn_resid=zen.${jd}.resid_fit.uvh5
fn_model=zen.${jd}.model_fit.uvh5
fn_gain=zen.${jd}.gain_fit.calfits


nfiles=${#data_files[@]}
files_per_chunk=$(( ${nfiles} / 4 + 1))

start=0
end=files_per_chunk
pids=()
for i in $(seq 0 3)
do
  gpu_index=$(( i % 2 ))
  if [ "${start}" -lt "${nfiles}" ]
  then
    echo calibrate_and_model_dpss.py --input_data_files ${data_files[@]:start:end} --model_outfilename\
     ${fn_model} --resid_outfilename ${fn_resid} --gain_outfilename ${fn_gain}\
      --verbose --red_tol 0.3 --horizon ${horizon} --offset ${offset}\
      --min_dly ${min_dly} --bllen_max ${bllen_max} --bllen_min ${bllen_min} --bl_ew_min ${bl_ew_min}\
      --ex_ants ${ex_ants} --gpu_memory_limit 8 --gpu_index ${gpu}
    calibrate_and_model_dpss.py --input_data_files ${data_files[@]:start:end} --model_outfilename\
     ${fn_model} --resid_outfilename ${fn_resid} --gain_outfilename ${fn_gain}\
      --verbose --red_tol 0.3 --horizon ${horizon} --offset ${offset}\
      --min_dly ${min_dly} --bllen_max ${bllen_max} --bllen_min ${bllen_min} --bl_ew_min ${bl_ew_min}\
      --ex_ants ${ex_ants} --gpu_memory_limit 8 --gpu_index ${gpu} & pids+=($!)
  fi
done
wait "${pids[@]}"
