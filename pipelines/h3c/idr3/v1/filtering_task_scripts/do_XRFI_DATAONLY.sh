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
# 6 - yaml directory
# 7 - basename
# 78+ - filenames
jd=$(get_jd ${7})
jd_int=${jd:0:7}
data_files="${@:8}"
flag_yaml=${6}/${jd_int}.yaml

echo xrfi_run_data_only.py --data_files ${data_files} --kt_size=${1} --kf_size=${2} --sig_init=${3} --sig_adj=${4} --Nwf_per_load=${5} --clobber --a_priori_flag_yaml ${flag_yaml}
xrfi_run_data_only.py --data_files ${data_files} --kt_size=${1} --kf_size=${2} --sig_init=${3} --sig_adj=${4} --Nwf_per_load=${5} --clobber --a_priori_flag_yaml ${flag_yaml}
