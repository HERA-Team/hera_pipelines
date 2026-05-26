#! /bin/bash
set -e

# Runs single_lststack_baseline_scaffolded_and_feathered_inpainter.ipynb on one LST-stacked
# single-baseline cross file. The notebook reads its configuration directly from the
# [GLOBAL_OPTS], [AUTO_SMOOTH_OPTS], and [SINGLE_LSTSTACK_BASELINE_REINPAINT_OPTS] sections
# of the TOML via toml.load(TOML_FILE), and discovers the round-6 flag waterfalls by globbing
# *.flag_waterfall_round_6.h5 in the input file's directory.
#
# Output: <basename>.reinpainted.uvh5 (with nsamples=0 on re-inpainted pixels).

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match h6c_pspec_*band.toml [SINGLE_LSTSTACK_BASELINE_REINPAINT])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

outdir=$(cd "$(dirname "$fn")" && pwd)
cross_file="$outdir/$(basename "$fn")"

echo "Performing LST-stack single-baseline re-inpainting on ${cross_file}"

# Env vars consumed by the notebook
export TOML_FILE=${toml_file}
export SINGLE_BL_FILE=${cross_file}
export OUT_FILE=${cross_file%.uvh5}.reinpainted.uvh5

# Execute notebook
nb_outfile=${cross_file%.uvh5}.single_lststack_baseline_scaffolded_and_feathered_inpainter.html
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/single_lststack_baseline_scaffolded_and_feathered_inpainter.ipynb
echo "Finished LST-stack single-baseline re-inpainting notebook for ${fn} at $(date)"

# Verify output
out_uvh5="${cross_file%.uvh5}.reinpainted.uvh5"
if [ ! -f "${out_uvh5}" ]; then
    echo "Expected re-inpainted output ${out_uvh5} not produced." >&2
    exit 1
fi
echo "Resulting ${out_uvh5} found."

# Symlink HTML into nb_output_repo
if [ -f "${nb_outfile}" ]; then
    nb_dest_dir="${nb_output_repo}/single_lststack_baseline_scaffolded_and_feathered_inpainter"
    mkdir -p "${nb_dest_dir}"
    ln -sf "$(realpath "${nb_outfile}")" "${nb_dest_dir}/$(basename "${nb_outfile}")"
    nb_index_script="${src_dir}/../../analysis/task_scripts/build_notebook_index.py"
    python "${nb_index_script}" "${nb_dest_dir}"
fi
