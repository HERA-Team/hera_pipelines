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

read -a data_files_arr <<< ${data_files}

nfiles=${#data_files_arr[@]}
files_per_chunk=$(( ${nfiles} / 2 ))

startind=0
stopind=$files_per_chunk
pids=()
echo ${nfiles}
echo ${startind}
echo ${data_files_arr[$startind]}
for i in $(seq 0 1)
do
  gpu_index=$(( i % 2 ))
  echo ${startind}
  echo ${nfiles}
  if [ "${startind}" -lt "${nfiles}" ]
  then

    fn=${data_files_arr[$startind]}


    fn_resid=${fn/.uvh5/.resid_fit.uvh5}
    fn_model=${fn/.uvh5/.model_fit.uvh5}
    fn_gain=${fn/.uvh5/.gain_fit.calfits}

    echo ${fn_resid}
    echo calibrate_and_model_dpss.py --input_data_files ${data_files_arr[@]:$startind:$stopind} --model_outfilename\
     ${fn_model} --resid_outfilename ${fn_resid} --gain_outfilename ${fn_gain}\
      --verbose --red_tol 0.3 --horizon ${horizon} --offset ${offset}\
      --min_dly ${min_dly} --bllen_max ${bllen_max} --bllen_min ${bllen_min} --bl_ew_min ${bl_ew_min}\
      --ex_ants ${ex_ants} --gpu_index ${gpu_index}
    calibrate_and_model_dpss.py --input_data_files ${data_files_arr[@]:$startind:$stopind} --model_outfilename\
     ${fn_model} --resid_outfilename ${fn_resid} --gain_outfilename ${fn_gain}\
      --verbose --red_tol 0.3 --horizon ${horizon} --offset ${offset}\
      --min_dly ${min_dly} --bllen_max ${bllen_max} --bllen_min ${bllen_min} --bl_ew_min ${bl_ew_min}\
      --ex_ants ${ex_ants} --gpu_index ${gpu_index} & pids+=($!)

      startind=$(( ${startind} + ${files_per_chunk} ))
      stopind=$(( ${stopind} + ${files_per_chunk} ))
  fi
done
wait "${pids[@]}"
