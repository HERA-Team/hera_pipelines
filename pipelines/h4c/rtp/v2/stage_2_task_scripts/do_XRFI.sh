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
# 3 - sig_init_med
# 4 - sig_adj_med
# 5 - sig_init_mean
# 6 - sig_adj_mean
# 7 - path_to_a_priori_flags: folder containing a priori flag YAML files
# 8 - Nwf_per_load
# 9+ - filenames

kt_size="${1}"
kf_size="${2}"
sig_init_med="${3}"
sig_adj_med="${4}"
sig_init_mean="${5}"
sig_adj_mean="${6}"
path_to_a_priori_flags="${7}"
Nwf_per_load="${8}"
data_files="${@:9}"

# build up omnical and abscal files, converting to correct uvh5 file
autos_files=()
model_files=()
ocalfits_files=()
acalfits_files=()
for data_file in ${data_files[@]}; do
    uvh5_fn=${fn}
    autos_file=`echo ${uvh5_fn%.*}.autos.uvh5`
    autos_files+=( $autos_file )
    model_files+=( ${uvh5_fn%.*}.omni_vis.uvh5 )
    ocalfits_files+=( ${uvh5_fn%.*}.omni.calfits )
    acalfits_files+=( ${uvh5_fn%.*}.abs.calfits )
done

# get a priori flag yaml file
jd_int=$(get_int_jd `basename ${autos_files[0]}`)
flag_yaml=`echo "${path_to_a_priori_flags}/${jd_int}.yaml"`

# run script
cmd="xrfi_run.py --ocalfits_files ${ocalfits_files[@]} \
                 --model_files ${model_files[@]} \
                 --data_files ${autos_files[@]} \
                 --acalfits_files ${acalfits_files[@]} \
                 --kt_size ${kt_size} \
                 --kf_size ${kf_size} \
                 --sig_init_med ${sig_init_med} \
                 --sig_adj_med ${sig_adj_med} \
                 --sig_init_mean ${sig_init_mean} \
                 --sig_adj_mean ${sig_adj_mean} \
                 --Nwf_per_load ${Nwf_per_load} \
                 --a_priori_flag_yaml ${flag_yaml} \
                 --clobber \
                 --skip_omnical_zscore_filter \
                 --skip_abscal_zscore_filter \
                 --skip_cross_mean_filter \
                 --skip_auto_median_filter \
                 --skip_omnivis_median_filter"
echo $cmd
$cmd
