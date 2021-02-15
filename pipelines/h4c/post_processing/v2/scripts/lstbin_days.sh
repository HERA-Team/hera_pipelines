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
  echo lstbin_run.py${inputargs} --outdir ${outputdir} --rephase
  lstbin_run.py${inputargs} --outdir ${outputdir} --rephase

  for parity in ${parities[@]}
  do
    if [ "${systematics}" == "after" ]
    then
      for str in ${inputdirs[@]}
      do
        inputargs=${inputargs}" '${str}/zen.*.${sd}.${label}.xtalk_filtered_res.smooth_avg_vis.${parity}.uvh5'"
      done
      echo lstbin_run.py${inputargs} --outdir ${outputdir} --rephase
      lstbin_run.py${inputargs} --outdir ${outputdir} --rephase
      for str in ${inputdirs[@]}
      do
        inputargs=${inputargs}" '${str}/zen.*.${sd}.${label}.fg_filtered_res.smooth_avg_vis.${parity}.uvh5'"
      done
      echo lstbin_run.py${inputargs} --outdir ${outputdir} --rephase
      lstbin_run.py${inputargs} --outdir ${outputdir} --rephase

    elif [ "${systematics}" == "before" ]
    then
      for str in ${inputdirs[@]}
      do
        inputargs=${inputargs}" '${str}/zen.*.${sd}.${label}.chunked.smooth_avg_vis.${parity}.uvh5'"
      done
      echo lstbin_run.py${inputargs} --outdir ${outputdir} --rephase
      lstbin_run.py${inputargs} --outdir ${outputdir} --rephase
    fi
  done
done
