#! /bin/bash
set -e

# This script simulates and applies systematics to an input file.
# Note that the path to where the perfectly calibrated files are stored
# is contained in the mock_data.py script.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - reference filename
# 2 - sky component (e.g. foreground)
# 3 - path to configuration files
# 4 - path to where the uncalibration script lives
# 5 - path to the IDR3.2 data products
# 6 - path to where all the calibration products etc. will be saved

fn="${1}"
sky_cmp="${2}"
config_path="${3}"
script_dir="${4}"
data_dir="${5}"
save_dir_base="${6}"

# Get the data filename correct, then append the data path.
jd_int=$(get_int_jd `basename ${fn}`)
uvh5_fn=$(remove_pol $fn)
uvh5_fn="${data_dir}/${jd_int}/${uvh5_fn%.HH.uv}.sum.autos.uvh5"

# Figure out which configuration file to use.
config_file="${config_path}/${jd_int}.yaml"

# Figure out where to write the new data.
outdir="${save_dir_base}/${jd_int}"

# Remember where we came from, and move to where we need to be.
cwd="$(pwd)"
cd $script_dir

# Do the interpolation and systematics simulation.
echo python mock_data.py ${uvh5_fn} ${sky_cmp} --config ${config_file} \
                         --outdir ${save_dir} --clobber --inflate
python mock_data.py ${uvh5_fn} ${sky_cmp} --config ${config_file} \
                    --outdir ${save_dir} --clobber --inflate
cd $cwd
