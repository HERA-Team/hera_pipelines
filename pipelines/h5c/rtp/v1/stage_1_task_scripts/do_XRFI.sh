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
# 3 - sig_init_med
# 4 - sig_adj_med
# 5 - sig_init_mean
# 6 - sig_adj_mean
# 7 - Nwf_per_load
# 8 - ant_metrics_ext
# 9+ - filenames
data_files=(${@:9})

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
    ant_metrics_files+=( ${fn%.uvh5}${8} )
done

# construct autos files from data files 
autos_files=()
for fn in ${data_files[@]}; do
    autos_files+=( "${fn%.uvh5}.autos.uvh5" )
done

# run XRFI
cmd="xrfi_run_data_only.py --data_files ${autos_files[@]} \
                           --kt_size=${1} \
                           --kf_size=${2} \
                           --sig_init_med=${3} \
                           --sig_adj_med=${4} \
                           --sig_init_mean=${5} \
                           --sig_adj_mean=${6} \
                           --Nwf_per_load=${7} \
                           --skip_cross_mean_filter \
                           --metrics_files ${auto_metrics_file} ${ant_metrics_files[@]} \
                           --skip_cross_pol_vis \
                           --clobber"
echo $cmd
$cmd
echo Finished runing XRFI at $(date)
