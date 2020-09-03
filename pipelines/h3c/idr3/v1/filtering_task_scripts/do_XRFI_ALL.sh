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
# 7+ - filenames
jd=$(get_jd ${7})
flag_yaml=${6}/${jd}.yaml
data_files="${@:7}"

ocal_files=${data_files/.uvh5/.omni.calfits}
acal_files=${data_files/.uvh5/.abs.calfits}
ovis_files=${data_files/.uvh5/.omni_vis.uvh5}

echo xrfi_run.py --data_files ${data_files} --ocalfits_files ${ocal_files} \
                 --acalfits_files ${acal_files} --model_files ${ovis_files} \
                 --a_priori_flag_yaml ${flag_yaml} --kt_size=${1} \
                 --kf_size=${2} --sig_init=${3} --sig_adj=${4} --Nwf_per_load=${5} --clobber
xrfi_run.py --data_files ${data_files} --ocalfits_files ${ocal_files} \
                 --acalfits_files ${acal_files} --model_files ${ovis_files} \
                 --a_priori_flag_yaml ${flag_yaml} --kt_size=${1} \
                 --kf_size=${2} --sig_init=${3} --sig_adj=${4} --Nwf_per_load=${5} --clobber
