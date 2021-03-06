#! /bin/bash
set -e

# This script runs SSINS on raw data

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.

# 1 - the significance threshold for streak shapes
# 2 - the significance threshold to use for the other shapes
# 3 - The threshold for flagging a highly contaminated frequency channel
# 4+ - The filename(s) to read in

all_args=("$@")
streak_sig=${1}
other_sig=${2}
tb_aggro=${3}
fns=("${all_args[@]:3}")

echo filenames are "${fns[@]}"

# Get the first filename in the list (should work if only one file)
first_file="${fns%" "*}"
# Set the prefix based on the first filename
prefix="${first_file%.uvh5}"

echo Run_HERA_SSINS.py -f "${fns[@]}" -s $streak_sig -o $other_sig -p $prefix -t $tb_aggro -c
Run_HERA_SSINS.py -f "${fns[@]}" -s $streak_sig -o $other_sig -p $prefix -t $tb_aggro -c

# Move all outputs to folder
echo rm -rf ${prefix}.SSINS
rm -rf ${prefix}.SSINS
echo mkdir ${prefix}.SSINS
mkdir ${prefix}.SSINS
for sf in ${prefix}.SSINS.*; do
    bn=$(basename ${sf})
    echo mv ${sf} ${prefix}.SSINS/${bn}
    mv ${sf} ${prefix}.SSINS/${bn}
done
