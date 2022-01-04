#! /bin/bash
set -e

# This script simulates and applies systematics to an input file.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename: reference filename
# 2 - config_path: path to configuration files
# 3 - data_path: path to raw simulation data
# 4 -
# 5 -
# 6 -
# 7 -
# 8 -
# 9 -
# 10 -
# 11 - 
# 12 - 

fn="${1}"
config_path="${2}"
data_path="${3}"

# make sure input file is correct uvh5 file
uvh5_fn=$(remove_pol $fn)
uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software

# get systematic parameter yaml
jd_int=$(get_int_jd `basename ${uvh5_fn}`)
config_file="${config_path}/${jd_int}.yaml"

cwd="$(pwd)"
cd $script_dir

# run systematics simulation
echo python apply_systematics.py ${uvh5_fn} --config ${config_file} # and so on
python apply_systematics.py ${uvh5_fn} --config ${config_file} # and so on
cd $cwd
