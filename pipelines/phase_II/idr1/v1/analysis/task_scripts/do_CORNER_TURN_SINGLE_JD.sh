#! /bin/bash
set -e

# The corner turn itself: for the antpairs the corner-turn map assigns to a block of files, reads those
# baselines (all pols) from every redundantly averaged file of the night and writes each as one whole-night
# single-baseline file, keyed by its redundant group so that names agree across nights; missing
# integrations are inserted flagged with nsamples = 0 and the data rephased onto a uniform time grid.
# The folder and map name come from the toml's [DATA_PRODUCTS] so that nothing here is hardcoded.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [CORNER_TURN_SINGLE_JD])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
red_avg_file=$(swap_suffix ${SUM_FILE} ${toml_file} RED_AVG)
map_path="$(dirname ${SUM_FILE})/$(get_filename ${toml_file} CORNER_TURN_MAP)"
out_folder=$(dirname ${map_path})
map_yaml=$(basename ${map_path})

# One job in every block_size files with antpairs corner-turns the whole block. The configured value is passed
# through Makeflow's NOTEBOOK_OPTS interpolation, while the Python default remains one for per-antpair use.
block_size=${5:-1}
echo python "${src_dir}/corner_turn_single_jd.py" "${red_avg_file}" "${map_yaml}" "${out_folder}" --block-size "${block_size}"
python "${src_dir}/corner_turn_single_jd.py" "${red_avg_file}" "${map_yaml}" "${out_folder}" --block-size "${block_size}"
