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
sig_clip=${1}
sigma=${2}
min_N=${3}
rephase=${4}
ntimes_per_file=${5}
lst_start=${6}
fixed_lst_start=${7}
dlst=${8}
vis_units=${9}
output_file_select=${10}
file_ext=${11}
outdir=${12}
Nbls_to_load=${13}
flag_thresh=${14}
average_redundant_baselines=${15}
yaml_dir=${16}
calibration=${17}
data_files=($@)
# if calibration suffix is not empty, parse it and apply it
if [ ! -z "${calibration}" ]
then
    # if there's a calibration string, then the data files start at the 17th position
    data_files=(${data_files[*]:17})
    # parse calibration suffix for each nested list in data_files
    input_cals=()
    for df in "${data_files[@]}"; do
        # remove brackets
        ic=$(sed -e 's/^"//' -e 's/"$//' <<< $df)
        ic=$(sed -e "s/^'//" -e "s/'$//" <<< $ic)
        # replace with calibration
        ic=${ic/.diff./.sum.}
        ic=${ic/.autos./.}
        ic="'${ic%.uvh5*}.${calibration}'"
        # add brackets
        input_cals+=("$ic")
    done
    input_cals="--input_cals ${input_cals[@]}"
else
   input_cals=""
   # if there's no calibration string, then they start at the 16th position
   data_files=(${data_files[*]:16})
fi

# set special kwargs
if [ $sig_clip == True ]; then
    sig_clip="--sig_clip"
else
    sig_clip=""
fi
if [ $rephase == True ]; then
    rephase="--rephase"
else
    rephase=""
fi
if [ $fixed_lst_start == True ]; then
    fixed_lst_start="--fixed_lst_start"
else
    fixed_lst_start=""
fi

if [ "${average_redundant_baselines}" = "True" ]
then
  red_arg=--average_redundant_baselines
else
  red_arg=""
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

echo lstbin_run.py --flag_thresh ${flag_thresh}  ${red_arg} --dlst ${dlst} --file_ext ${file_ext}\
 --outdir ${outdir} --ntimes_per_file ${ntimes_per_file} ${rephase} ${sig_clip} --sigma ${sigma}\
  --min_N ${min_N} --lst_start ${lst_start} ${fixed_lst_start} --vis_units ${vis_units}\
   --output_file_select ${output_file_select} --Nbls_to_load ${Nbls_to_load}\
   ${yaml_arg} ${input_cals} --overwrite ${data_files[@]}
lstbin_run.py --flag_thresh ${flag_thresh}  ${red_arg} --dlst ${dlst} --file_ext ${file_ext}\
    --outdir ${outdir} --ntimes_per_file ${ntimes_per_file} ${rephase} ${sig_clip} --sigma ${sigma}\
     --min_N ${min_N} --lst_start ${lst_start} ${fixed_lst_start} --vis_units ${vis_units}\
      --output_file_select ${output_file_select} --Nbls_to_load ${Nbls_to_load}\
      ${yaml_arg} ${input_cals} --overwrite ${data_files[@]}
