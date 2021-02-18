#!/bin/bash
#conda activate hera3dev
label="${1}"
outputdir="${2}"
systematics="${3}"
inputdirs="${@:4}"

# run lst binner on smooth_avg_vis files.

parities=("0" "1")
sumdiff=("sum" "diff")
echo ${inputdirs[@]}
for sd in ${sumdiff[@]}
do
  inputargs=""
  for str in ${inputdirs[@]}
  do
    inputargs=${inputargs}" '${str}/zen.*.${sd}.${label}.auto.foreground_filled.uvh5'"
  done
  echo lstbin_run.py${inputargs} --outdir ${outputdir} --rephase --overwrite --file_ext "{type}.{time:7.5f}.${sd}.${label}.auto.uvh5"
  lstbin_run.py${inputargs} --outdir ${outputdir} --rephase --overwrite --file_ext "{type}.{time:7.5f}.${sd}.${label}.auto.uvh5"

  for parity in ${parities[@]}
  do
    if [ "${systematics}" == "after" ]
    then
      inputargs=""
      for str in ${inputdirs[@]}
      do
        inputargs=${inputargs}" '${str}/zen.*.${sd}.${label}.xtalk_filtered_res.smooth_avg_vis.${parity}.uvh5'"
      done
      echo lstbin_run.py${inputargs} --outdir ${outputdir} --rephase --average_redundant_baselines --overwrite --file_ext "{type}.{time:7.5f}.${sd}.${label}.xtalk_filtered.smooth_avg_vis.${parity}.uvh5"
      lstbin_run.py${inputargs} --outdir ${outputdir} --rephase --average_redundant_baselines --overwrite --file_ext "{type}.{time:7.5f}.${sd}.${label}.xtalk_filtered.smooth_avg_vis.${parity}.uvh5"
      inputargs=""
      for str in ${inputdirs[@]}
      do
        inputargs=${inputargs}" '${str}/zen.*.${sd}.${label}.fg_filtered_res.smooth_avg_vis.${parity}.uvh5'"
      done
      echo lstbin_run.py${inputargs} --outdir ${outputdir} --rephase --average_redundant_baselines --overwrite --file_ext "{type}.{time:7.5f}.${sd}.${label}.smooth_avg_vis.${parity}.uvh5"
      lstbin_run.py${inputargs} --outdir ${outputdir} --rephase --average_redundant_baselines --overwrite --file_ext "{type}.{time:7.5f}.${sd}.${label}.smooth_avg_vis.${parity}.uvh5"

    elif [ "${systematics}" == "before" ]
    then
      inputargs=""
      for str in ${inputdirs[@]}
      do
        inputargs=${inputargs}" '${str}/zen.*.${sd}.${label}.chunked.smooth_avg_vis.${parity}.uvh5'"
      done
      echo lstbin_run.py${inputargs} --outdir ${outputdir} --rephase --average_redundant_baselines --overwrite --file_ext "{type}.{time:7.5f}.${sd}.${label}.chunked.smooth_avg_vis.${parity}.uvh5"
      lstbin_run.py${inputargs} --outdir ${outputdir} --rephase --average_redundant_baselines --overwrite --file_ext "{type}.{time:7.5f}.${sd}.${label}.chunked.smooth_avg_vis.${parity}.uvh5"
    fi
  done
done
