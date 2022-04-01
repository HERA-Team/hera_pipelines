#!/bin/bash
set -e

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
# 7 - dlst
# 8 - vis_units
# 9 - output_file_select
# 10 - file_ext
# 11 - outdir
# 12 - Nbls_to_load
# 13 - calibration
# 14+ - series of glob-parsable search strings (in quotations!) to files to LSTBIN

# get positional arguments
sig_clip=${1}
sigma=${2}
min_N=${3}
rephase=${4}
ntimes_per_file=${5}
lst_start=${6}
dlst=${7}
vis_units=${8}
output_file_select=${9}
file_ext=${10}
outdir=${11}
Nbls_to_load=${12}
calibration=${13}
data_files=($@)

# if calibration suffix is not empty, parse it and apply it
if [ ! -z "${calibration}" ]
then
    # if there's a calibration string, then the data files start at the 14th position
    data_files=(${data_files[*]:13})
    # parse calibration suffix for each nested list in data_files
    input_cals=()
    for df in "${data_files[@]}"; do
        # remove brackets
        ic=$(sed -e 's/^"//' -e 's/"$//' <<< $df)
        ic=$(sed -e "s/^'//" -e "s/'$//" <<< $ic)
        # replace with calibration
        ic="'${ic%.uvh5*}.${calibration}'"
        # add brackets
        input_cals+=("$ic")
    done
    input_cals="--input_cals ${input_cals[@]}"
else
   input_cals=""
   # if there's no calibration string, then they start at the 13th position
   data_files=(${data_files[*]:12})
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

# run the command
cmd="lstbin_run.py --dlst ${dlst} \
                   --lst_start ${lst_start} \
                   --file_ext ${file_ext} \
                   --outdir ${outdir} \
                   --ntimes_per_file ${ntimes_per_file} \
                   ${rephase} \
                   ${sig_clip} \
                   --sigma ${sigma} \
                   --min_N ${min_N} \
                   --vis_units ${vis_units} \
                   --output_file_select \
                   ${output_file_select} \
                   --Nbls_to_load ${Nbls_to_load} \
                   ${input_cals} \
                   --overwrite \
                   ${data_files[@]}"
echo $cmd
$cmd