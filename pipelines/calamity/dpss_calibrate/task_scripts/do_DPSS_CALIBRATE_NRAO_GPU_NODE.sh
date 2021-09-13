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
model_regularization="${7}"
ex_ants="${8}"
select_ants="${9}"
label="${10}"
data_files="${@:11}"

if [ "${ex_ants}" = "none" ]
then
  ex_ant_arg=""
else
  ex_ants="${ex_ants//,/$' '}"
  ex_ant_arg="--ex_ants ${ex_ants}"
fi

if [ "${select_ants}" = "none" ]
then
  select_ant_arg=""
else
  select_ants="${select_ants//,/$' '}"
  select_ant_arg="--select_ants ${select_ants}"
fi

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


    fn_resid=${fn/.uvh5/.${labe}.resid_fit.uvh5}
    fn_model=${fn/.uvh5/.${labe}.model_fit.uvh5}
    fn_gain=${fn/.uvh5/.${label}.gain_fit.calfits}

    echo ${fn_resid}
    echo calibrate_and_model_dpss.py --input_data_files ${data_files_arr[@]:$startind:$stopind} --model_outfilename\
     ${fn_model} --resid_outfilename ${fn_resid} --gain_outfilename ${fn_gain}\
      --verbose --red_tol 0.3 --horizon ${horizon} --offset ${offset} ${select_ant_arg}\
      --min_dly ${min_dly} --bllen_max ${bllen_max} --bllen_min ${bllen_min} --bl_ew_min ${bl_ew_min}\
      ${ex_ant_arg} --gpu_index ${gpu_index} --learning_rate 0.01 --model_regularization "${model_regularization}"
    calibrate_and_model_dpss.py --input_data_files ${data_files_arr[@]:$startind:$stopind} --model_outfilename\
     ${fn_model} --resid_outfilename ${fn_resid} --gain_outfilename ${fn_gain}\
      --verbose --red_tol 0.3 --horizon ${horizon} --offset ${offset} ${select_ant_arg}\
      --min_dly ${min_dly} --bllen_max ${bllen_max} --bllen_min ${bllen_min} --bl_ew_min ${bl_ew_min}\
      ${ex_ant_arg} --gpu_index ${gpu_index} --learning_rate 0.01 --model_regularization "${model_regularization}" & pids+=($!)

      startind=$(( ${startind} + ${files_per_chunk} ))
      stopind=$(( ${stopind} + ${files_per_chunk} ))
  fi
done
wait "${pids[@]}"
