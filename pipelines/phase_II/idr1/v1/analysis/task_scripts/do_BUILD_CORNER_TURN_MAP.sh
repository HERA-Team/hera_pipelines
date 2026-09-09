#! /bin/bash
set -e

# Builds the night's corner-turn map: a yaml assigning every antpair in the redundantly averaged files
# to one of those files (round robin, so that the per-file CORNER_TURN_SINGLE_JD jobs share the work),
# naming each antpair's whole-night output file by its redundant group's key, and recording each file's
# times. Runs once per night, after every file's redundant average exists. The folder and yaml name
# come from the toml's [DATA_PRODUCTS] so that nothing here is hardcoded.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [BUILD_CORNER_TURN_MAP])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
red_avg_file=$(swap_suffix ${SUM_FILE} ${toml_file} RED_AVG)
map_path="$(dirname ${SUM_FILE})/$(get_filename ${toml_file} CORNER_TURN_MAP)"
out_folder=$(dirname ${map_path})
map_yaml=$(basename ${map_path})

echo python ${src_dir}/build_corner_turn_map.py ${red_avg_file} ${map_yaml} ${out_folder}
python ${src_dir}/build_corner_turn_map.py ${red_avg_file} ${map_yaml} ${out_folder}

if [ -f "${map_path}" ]; then
    echo Resulting ${map_path} found.
else
    echo ${map_path} not produced.
    exit 1
fi
