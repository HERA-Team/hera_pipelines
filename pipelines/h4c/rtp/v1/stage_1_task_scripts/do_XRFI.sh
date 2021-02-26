#! /bin/bash
set -e

# This script runs xrfi on just raw data.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
### XRFI parameters - see hera_qm.utils for details
# 1 - kt_size
# 2 - kf_size
# 3 - sig_init
# 4 - sig_adj
# 5 - Nwf_per_load
# 6 - ant_metrics_ext
# 7+ - filenames
data_files="${@:7}"

# get auto_metrics_file
jd=$(get_int_jd ${data_files[0]})
decimal_jd=$(get_jd ${data_files[0]})
pattern="${fn%${decimal_jd}.sum.uvh5}${jd}.?????.sum.auto_metrics.h5"
pattern_files=( $pattern )
auto_metrics_file=${pattern_files[0]}

# get ant_metrics_files
ant_metrics_files=()
for fn in ${data_files[@]}; do
    ant_metrics_files+=( ${fn%.uvh5}${6} )
done


cmd="xrfi_run_data_only.py --data_files ${data_files} \
                           --kt_size=${1} \
                           --kf_size=${2} \
                           --sig_init=${3} \
                           --sig_adj=${4} \
                           --Nwf_per_load=${5} \
                           --skip_cross_mean_filter \
                           --metrics_files ${auto_metrics_file} ${ant_metrics_files[@]} \
                           --clobber"
echo $cmd
$cmd
