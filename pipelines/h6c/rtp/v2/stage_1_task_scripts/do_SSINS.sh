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
data_files=(${@:4})

echo filenames are "${data_files[@]}"

# Get the first filename in the list (should work if only one file)
first_file="${data_files%" "*}"
# Set the prefix based on the first filename
prefix="${first_file%.uvh5}"

# get auto_metrics_file to exclude bad antennas
fn=${data_files[0]}
bn=`basename ${fn}`
jd=$(get_int_jd ${bn})
decimal_jd=$(get_jd ${bn})
pattern="${fn%${decimal_jd}.sum.uvh5}${jd}.?????.sum.auto_metrics.h5"
pattern_files=( $pattern )
auto_metrics_file=${pattern_files[0]}

# get ant_metrics_files to exclude bad antennas
ant_metrics_files=()
for fn in ${data_files[@]}; do
    ant_metrics_files+=( ${fn%.uvh5}.ant_metrics.hdf5 )
done

echo Run_HERA_SSINS.py -f ${data_files[@]} -s $streak_sig -o $other_sig -p $prefix -t $tb_aggro --metrics_files ${auto_metrics_file} ${ant_metrics_files[@]} -c
Run_HERA_SSINS.py -f ${data_files[@]} -s $streak_sig -o $other_sig -p $prefix -t $tb_aggro --metrics_files ${auto_metrics_file} ${ant_metrics_files[@]} -c
echo Finished running SSINS at $(date)

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
