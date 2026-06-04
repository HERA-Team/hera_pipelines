#! /bin/bash
set -e

# Runs single_lststack_baseline_pI_FRF_SNR.ipynb on one LST-stacked single-baseline
# cross file. The notebook reads its configuration from the [FRF_SNR_CONFIG] section
# of the toml directly via toml.load(TOML_FILE) — same pattern as the lststack notebook.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match h6c_pspec_16band.toml [SINGLE_LSTSTACK_BASELINE_FILTERED_SNR])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

outdir=$(cd "$(dirname "$fn")" && pwd)
cross_file="$outdir/$(basename "$fn")"

echo "Performing LST-stack single-baseline filtered-SNR computation on ${cross_file}"

# Skip autocorrelations and outriggers
if ! python ${src_dir}/check_single_bl_file.py ${cross_file} --skip_autos --skip_outriggers; then
    echo "Skipping ${cross_file} (autocorrelation, outrigger, or fully-flagged polarization)."
    exit 0
fi

# Env vars consumed by the notebook
export TOML_FILE=${toml_file}
export SINGLE_BL_FILE=${cross_file}
export OUT_SNR_FILE=${cross_file%.uvh5}.pI_FRF_SNR.uvh5

# Execute notebook
nb_outfile=${cross_file%.uvh5}.single_lststack_baseline_pI_FRF_SNR.html
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/single_lststack_baseline_pI_FRF_SNR.ipynb
echo "Finished single LST-stack baseline filtered-SNR notebook for ${fn} at $(date)"

# (Intentionally no output-existence check: the notebook may legitimately produce no SNR
#  file for baselines that are too sparsely sampled.)

# Symlink HTML into nb_output_repo
if [ -f "${nb_outfile}" ]; then
    nb_dest_dir="${nb_output_repo}/single_lststack_baseline_pI_FRF_SNR"
    mkdir -p "${nb_dest_dir}"
    ln -sf "$(realpath "${nb_outfile}")" "${nb_dest_dir}/$(basename "${nb_outfile}")"
    nb_index_script="${src_dir}/../../analysis/task_scripts/build_notebook_index.py"
    python "${nb_index_script}" "${nb_dest_dir}"
fi
