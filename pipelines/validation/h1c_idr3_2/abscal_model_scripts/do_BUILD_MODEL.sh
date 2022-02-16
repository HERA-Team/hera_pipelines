#! /bin/bash
set -e

# This script creates files that match the abscal model and adds noise

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - link to original abscal model file
# 2 - sky component (e.g. foreground)
# 3 - path to where output file will be saved

fn="${1}"
sky_cmp="${2}"
save_dir="${3}"

config_file=${src_dir}/abscal_model_config.yaml

# Do the interpolation and systematics simulation.
echo ${src_dir}/python mock_data.py ${fn} ${sky_cmp} --config ${config_file} --outdir ${save_dir} --inflate
${src_dir}/python mock_data.py ${fn} ${sky_cmp} --config ${config_file} --outdir ${save_dir} --inflate
