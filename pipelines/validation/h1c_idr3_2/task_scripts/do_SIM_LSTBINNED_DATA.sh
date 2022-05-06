#! /bin/bash
set -e

# This script simulates and applies systematics to an input file 

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - reference file path
# 2 - sky component (e.g. eor)
# 3 - path to simulation data files
# 4 - path to configuration file (use "None" for no systematics or uncalibration)
# 5 - whether or not to inflate the output by redundancy

ref_file="${1}"
sky_cmp="${2}"
sim_dir="${3}"
config_path="${4}"
inflate="${5}"

# Assumes this is built off soft links in the output folder to files like zen.grp1.of1.LST.0.02584.sum.LPL.uvh5
if [ "${config_path}" != "None" ]; then
    outfile="${ref_file%.sum*}".true_${sky_cmp}.with_xtalk.uvh5
else
    outfile="${ref_file%.sum*}".true_${sky_cmp}.uvh5
fi

# Do the interpolation and systematics simulation.
cmd="python ${src_dir}/mock_lstbinned_data.py ${ref_file} \
                                              ${sky_cmp} \
                                              ${outfile} \
                                              --sim_dir ${sim_dir} \
                                              --clobber \
                                              --input_is_compressed"
if [ "${config_path}" != "None" ]; then
    cmd="${cmd} --config ${config_path}"
fi
if [ "${inflate}" != "True" ]; then
    cmd="${cmd} --inflate"
echo $cmd
$cmd
