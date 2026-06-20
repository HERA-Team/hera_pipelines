#! /bin/bash
set -e

# Runs single_baseline_sky_model_2D_filter.ipynb on one LST-stacked single-baseline cross
# file (without the FR=0 filter). The notebook reads its configuration from the toml directly
# via toml.load(TOML_FILE), and writes the smooth sky model to <file>.sky_model.uvh5.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match build_sky_model.toml [BUILD_SKY_MODEL])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

outdir=$(cd "$(dirname "$fn")" && pwd)
cross_file="$outdir/$(basename "$fn")"

echo "Building single-baseline sky model on ${cross_file}"

# The notebook decides what to skip internally (long baselines, fully-flagged data) and simply
# writes no output file in those cases.

# Env vars consumed by the notebook
export TOML_FILE=${toml_file}
export SINGLE_BL_FILE=${cross_file}

# Execute notebook
nb_outfile=${cross_file%.uvh5}.single_baseline_sky_model_2D_filter.html
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/single_baseline_sky_model_2D_filter.ipynb
echo "Finished single-baseline sky model notebook for ${fn} at $(date)"

# (No output-existence check: the notebook may legitimately produce no model file for
#  baselines that are too long or too sparsely sampled.)

# Symlink HTML into nb_output_repo and rebuild the notebook index
if [ -f "${nb_outfile}" ]; then
    nb_dest_dir="${nb_output_repo}/single_baseline_sky_model_2D_filter"
    mkdir -p "${nb_dest_dir}"
    ln -sf "$(realpath "${nb_outfile}")" "${nb_dest_dir}/$(basename "${nb_outfile}")"
    nb_index_script="${src_dir}/../../analysis/task_scripts/build_notebook_index.py"
    python "${nb_index_script}" "${nb_dest_dir}"
fi
