#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


# We need to run xrfi on calibration outputs as preliminary flags before we
# delay filter and run xrfi on visibilities.

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
### XRFI parameters - see hera_qm.utils for details
# 1 - kt_size
# 2 - kf_size
# 3 - sig_init
# 4 - sig_adj
# 5 - path_to_a_priori_flags: folder containing a priori flag YAML files
# 6 - Nwf_per_load
# 7+ - filenames

kt_size="${1}"
kf_size="${2}"
sig_init="${3}"
sig_adj="${4}"
path_to_a_priori_flags="${5}"
Nwf_per_load="${6}"
data_files="${@:7}"

# build up omnical and abscal files, converting to correct uvh5 file
uvh5_files=()
model_files=()
ocalfits_files=()
acalfits_files=()
for data_file in ${data_files[@]}; do
    uvh5_fn=$(remove_pol $data_file)
    uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software
    uvh5_files+=( $uvh5_fn )
    model_files+=( ${uvh5_fn%.*}.omni_vis.uvh5 )
    ocalfits_files+=( ${uvh5_fn%.*}.omni.calfits )
    acalfits_files+=( ${uvh5_fn%.*}.abs.calfits )

# get a priori flag yaml file
jd_int=$(get_int_jd `basename ${uvh5_files[0]}`)
flag_yaml=`echo "${path_to_a_priori_flags}/${jd_int}.yaml"`

# run script
cmd="xrfi_run.py --ocalfits_files ${ocalfits_files} \
                 --model_files ${model_files} \
                 --data_files ${uvh5_files} \
                 --acalfits_files ${acalfits_files} \
                 --kt_size ${kt_size} \
                 --kf_size ${kf_size} \
                 --sig_init ${sig_init} \
                 --sig_adj ${sig_adj} \
                 --Nwf_per_load ${Nwf_per_load} \
                 --a_priori_flag_yaml ${flag_yaml} \
                 --clobber \
                 --skip_abscal_zscore_filter \
                 --skip_cross_mean_filter"
echo $cmd
$cmd
