#! /bin/bash
set -e

# Runs single_baseline_postprocessing_and_pspec.ipynb on one re-inpainted single-baseline file.
# The notebook reads its configuration from the [GLOBAL_OPTS]/[POSTPROCESS_AND_PSPEC_OPTS] sections of the toml
# directly via toml.load(TOML_FILE) — same pattern as the other post-lstbin notebooks.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match h6c_pspec_*band.toml [SINGLE_BASELINE_POSTPROCESSING_AND_PSPEC])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

outdir=$(cd "$(dirname "$fn")" && pwd)
full_file_path="$outdir/$(basename "$fn")"
reinpainted_file_path="${full_file_path%.uvh5}.reinpainted.uvh5"
echo "Performing single baseline postprocessing and power spectrum estimation on ${reinpainted_file_path}"

# check if file is not just autocorrelations and that neither polarization is fully flagged
if python ${src_dir}/check_single_bl_file.py ${full_file_path} --skip_autos --skip_outriggers; then
    out_pspec_file=${reinpainted_file_path%.uvh5}.pspec.h5
    out_tavg_pspec_file=${reinpainted_file_path%.uvh5}.tavg.pspec.h5

    # Env vars consumed by the notebook
    export TOML_FILE=${toml_file}
    export SINGLE_BL_FILE=${reinpainted_file_path}
    export OUT_PSPEC_FILE=${out_pspec_file}
    export OUT_TAVG_PSPEC_FILE=${out_tavg_pspec_file}

    # Execute notebook
    nb_outfile=${reinpainted_file_path%.uvh5}.single_baseline_postprocessing_and_pspec.html
    jupyter nbconvert --output=${nb_outfile} \
        --to html \
        --ExecutePreprocessor.timeout=-1 \
        --execute ${nb_template_dir}/single_baseline_postprocessing_and_pspec.ipynb
    echo "Finished single baseline postprocessing and pspec notebook for ${fn} at $(date)"

    # Check that the output file was correctly produced
    if [ -f "${out_pspec_file}" ]; then
        echo Resulting ${out_pspec_file} found.
    else
        echo ${out_pspec_file} not produced.
        exit 1
    fi
else
    echo "File ${full_file_path} is either just autocorrelations or has a fully flagged polarization. Skipping the power spectrum notebook."
fi

# Symlink HTML into nb_output_repo for web viewing
if [ -f "${nb_outfile}" ]; then
    nb_dest_dir="${nb_output_repo}/single_baseline_postprocessing_and_pspec"
    mkdir -p "${nb_dest_dir}"
    ln -sf "$(realpath "${nb_outfile}")" "${nb_dest_dir}/$(basename "${nb_outfile}")"

    # Rebuild notebook index
    nb_index_script="${src_dir}/../../analysis/task_scripts/build_notebook_index.py"
    python "${nb_index_script}" "${nb_dest_dir}"
fi
