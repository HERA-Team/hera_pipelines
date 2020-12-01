#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
### XRFI parameters - see hera_qm.utils for details
# 1 - nsig_f
# 2 - nsig_t
# 3 - nsig_f_adj
# 4 - nsig_t_adj
# 5 - path_to_a_priori_flags: folder containing a priori flag YAML files
# 6+ - filenames

data_files="${@:6}"
uvh5_files=()
for data_file in ${data_files[@]}; do
    uvh5_fn=`basename "$data_file"`
    uvh5_fn=$(remove_pol $uvh5_fn)
    uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software
    uvh5_files+=( $uvh5_fn )
done


# get a priori flag yaml file
jd_int=$(get_int_jd `basename ${6}`)
flag_yaml=`echo "${5}/${jd_int}.yaml"`

echo xrfi_day_threshold_run.py --nsig_f=${1} --nsig_t=${2} --nsig_f_adj=${3} --nsig_t_adj=${4} --a_priori_flag_yaml=${flag_yaml} --clobber ${uvh5_files}
xrfi_day_threshold_run.py --nsig_f=${1} --nsig_t=${2} --nsig_f_adj=${3} --nsig_t_adj=${4} --a_priori_flag_yaml=${flag_yaml} --clobber ${uvh5_files}
