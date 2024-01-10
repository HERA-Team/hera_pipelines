#!/bin/bash
set -e
export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - sig_clip flag
# 2 - sigma threshold
# 3 - min_N threshold
# 4 - rephase flag
# 5 - ntimes_per_file
# 6 - lst_start
# 7 - fixed_lst_start
# 8 - dlst
# 9 - vis_units
# 10 - output_file_select
# 11 - file_ext
# 12 - outdir
# 13 - Nbls_to_load
# 14 - calibration
# 15+ - series of glob-parsable search strings (in quotations!) to files to LSTBIN

# get positional arguments
rephase=${1}
vis_units=${2}
output_file_select=${3}
fname_format=${4}
outdir=${5}
Nbls_to_load=${6}
yaml_dir=${7}
calibration=${8}
ignore_missing_calfiles=${9}
profile_funcs=${10}
save_channels=${11}
golden_lsts=${12}
sigma_clip_thresh=${13}
sigma_clip_min_N=${14}
sigma_clip_type=${15}
sigma_clip_subbands=${16}
only_last_file_per_night=${17}
freq_min=${18}
freq_max=${19}
inpaint_extension=${20}
sum_or_diff=${21}
datafile_extension=${22}
sigma_clip_in_inpaint=${23}
write_med_mad=${24}
datafile_label=${25}

if [ "${datafile_label}" != "" ]
then
    datafile_label=".${datafile_label}"
fi

if [ "${inpaint_extension}" == "none" ]
then
    inpaint_rules=""
else
    inpaint_rules="--where-inpainted-file-rules .${sum_or_diff}${datafile_label}.${datafile_extension} ${inpaint_extension}"
fi

if [ "${sigma_clip_in_inpaint}" == "True" ]
then
    sigma_clip_in_inpaint="--sigma-clip-in-inpainted-mode"
else
    sigma_clip_in_inpaint=""
fi

if [ "${write_med_mad}" == "True" ]
then
    write_med_mad="--write-med-mad"
else
    write_med_mad=""
fi

if [ "${sigma_clip_thresh}" == "none" ]
then
    sigma_clip_thresh=""
else
    sigma_clip_thresh="--sigma-clip-thresh ${sigma_clip_thresh}"
fi


if [ "${calibration}" == "none" ]
then
    calibration=""
else
    calibration="--calfile-rules .uvh5 ${calibration}"
fi

if [ "${freq_min}" == None ]
then
    freqmin=""
else
    freqmin="--freq-min ${freq_min}"
fi

if [ "${freq_max}" == None ]
then
    freqmax=""
else
    freqmax="--freq-max ${freq_max}"
fi

if [ "${only_last_file_per_night}" == True ]
then
    lastfile="--only-last-file-per-night"
else
    lastfile=""
fi

if [ $rephase == True ]; then
    rephase="--rephase"
else
    rephase=""
fi

if [ $ignore_missing_calfiles == True ]; then
    ignorecf="--ignore-missing-calfiles"
else
    ignorecf=""
fi

if [ "${yaml_dir}" == "none" ]
then
  yaml_arg=""
else
  yaml_arg="--ex_ant_yaml_files "
  for df in "${data_files[@]}"
  do
    jd=`echo ${df} | grep -o '[0-9]\{7\}'`
    yaml_arg="${yaml_arg} ${yaml_dir}${jd}.yaml"
  done
fi

if [ "${profile_funcs}" == "none" ]
then
    profilestr=""
else
    profilestr="--profile-funcs ${profile_funcs}"
fi

if [ "${golden_lsts}" == "none" ]
then
    glsts=""
else
    glsts="--golden-lsts ${golden_lsts}"
fi

if [ "${save_channels}" == "none" ]
then
    savestr=""
else
    savestr="--save-channels ${save_channels}"
fi

cmd="lstbin_simple.py ${outdir}/file-config.yaml --fname-format ${fname_format}\
 --outdir ${outdir} ${rephase} --vis_units ${vis_units}\
 --output_file_select ${output_file_select} --Nbls_to_load ${Nbls_to_load}\
 ${yaml_arg} ${calibration} ${ignorecf} --profile ${profilestr} \
 --profile-output lineprof-${output_file_select}.txt \
 ${sigma_clip_thresh} --sigma-clip-min-N ${sigma_clip_min_N}\
 ${lastfile} ${freqmin} ${freqmax} --overwrite ${glsts} ${savestr}\
 ${write_med_mad} ${inpaint_rules} ${sigma_clip_in_inpaint}"
   
echo $cmd
eval $cmd

