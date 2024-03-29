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
# 15+ - series of glob-parsable search strings (in quotations!) to files to LSTBIN

# get positional arguments
sig_clip=${1}
sigma=${2}
min_N=${3}
rephase=${4}
ntimes_per_file=${5}
lst_start=${6}
lst_stop=${7}
fixed_lst_start=${8}
dlst=${9}
vis_units=${10}
output_file_select=${11}
file_ext=${12}
outdir=${13}
Nbls_to_load=${14}
flag_thresh=${15}
average_redundant_baselines=${16}
data_files=($@)

data_files=(${data_files[*]:16})

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



echo lstbin_run.py --flag_thresh ${flag_thresh}  ${red_arg} --dlst ${dlst} --file_ext ${file_ext}\
 --outdir ${outdir} --ntimes_per_file ${ntimes_per_file} ${rephase} ${sig_clip} --sigma ${sigma}\
 --lst_start ${lst_start} ${fixed_lst_start} --vis_units ${vis_units} --lst_stop ${lst_stop}\
 --output_file_select ${output_file_select} --Nbls_to_load ${Nbls_to_load} --overwrite ${data_files[@]}
lstbin_run.py --flag_thresh ${flag_thresh}  ${red_arg} --dlst ${dlst} --file_ext ${file_ext}\
 --outdir ${outdir} --ntimes_per_file ${ntimes_per_file} ${rephase} ${sig_clip} --sigma ${sigma}\
 --lst_start ${lst_start} ${fixed_lst_start} --vis_units ${vis_units} --lst_stop ${lst_stop}\
 --output_file_select ${output_file_select} --Nbls_to_load ${Nbls_to_load} --overwrite ${data_files[@]}
