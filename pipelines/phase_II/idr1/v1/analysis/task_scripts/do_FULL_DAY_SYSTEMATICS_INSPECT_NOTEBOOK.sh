#! /bin/bash
set -e

# Runs full_day_systematics_inspect.ipynb once per night (on the night's first file, with every
# SINGLE_BASELINE_WIENER_INPAINT_NOTEBOOK job as a prereq): delay and fringe-rate views of the night's inpainted
# single-baseline data on a few baselines, before and after delay, cross-talk and main-beam fringe-rate filtering
# (H6C post_corner_turn_systematics_inspect). It writes no data products, only the rendered notebook.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [FULL_DAY_SYSTEMATICS_INSPECT_NOTEBOOK])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

# Env vars consumed by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export TOML_FILE=${toml_file}

# Execute the notebook, rendering straight into the output repository (one file per night)
jd=$(get_int_jd ${fn})
nb_dest_dir=${nb_output_repo}/full_day_systematics_inspect
nb_outfile=${nb_dest_dir}/full_day_systematics_inspect_${jd}.html
mkdir -p ${nb_dest_dir}
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/full_day_systematics_inspect.ipynb
echo Finished running full_day_systematics_inspect notebook at $(date)
python ${src_dir}/build_notebook_index.py ${nb_dest_dir}
