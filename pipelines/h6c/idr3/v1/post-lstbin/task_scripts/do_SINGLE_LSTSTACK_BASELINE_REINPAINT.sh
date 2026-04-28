#! /bin/bash
set -e

# Performs scaffolded, feathered 1D DPSS re-inpainting on LST-stack single-baseline files,
# using the OR'd Round-6 flag waterfalls. Calls the (adapted) per-night
# single_baseline_scaffolded_and_feathered_inpainter.ipynb in LSTSTACK_MODE.
#
# Output: <basename>.sum.reinpainted.uvh5 (with nsamples=0 over re-inpainted pixels)
#       + <basename>.sum.where_reinpainted.h5 sidecar

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters from the configuration file
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
FM_low_freq=${4}
FM_high_freq=${5}
eigenval_cutoff=${6}
auto_fr_spectrum_file=${7}
auto_inpaint_delay=${8}
inpaint_delay=${9}
cg_tol=${10}
inpaint_width_factor=${11}
inpaint_zero_dist_weight=${12}
gauss_fit_buffer_cut=${13}

# Path manipulation
outdir=$(cd "$(dirname "$fn")" && pwd)
cross_file="${outdir}/$(basename "$fn")"

echo "Performing LST-stacked single-baseline re-inpainting on ${cross_file}"

# Skip autocorrelations or if any polarization is fully flagged
if ! python ${src_dir}/check_single_bl_file.py ${cross_file} --skip_autos; then
    echo "Skipping ${cross_file} (it's an autocorrelation or a fully-flagged polarization)."
    exit 0
fi

# Mode + IO interface (consumed by the LSTSTACK_MODE branch in the notebook)
export LSTSTACK_MODE="TRUE"
export SINGLE_BL_FILE="${cross_file}"

# Round-6 flag application: glob all per-source + incoherent waterfalls in this dir
export APPLY_PRIOR_FLAGS="TRUE"
export PRIOR_FLAG_GLOB="zen.LST.*.flag_waterfall_round_6.h5"

# Inpainting settings
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export AUTO_FR_SPECTRUM_FILE=${auto_fr_spectrum_file}
export AUTO_INPAINT_DELAY=${auto_inpaint_delay}
export INPAINT_DELAY=${inpaint_delay}
export CG_TOL=${cg_tol}
export INPAINT_WIDTH_FACTOR=${inpaint_width_factor}
export INPAINT_ZERO_DIST_WEIGHT=${inpaint_zero_dist_weight}
export GAUSS_FIT_BUFFER_CUT=${gauss_fit_buffer_cut}

# IO extensions: input is the raw .sum.uvh5, scaffold is the same data,
# output gets .reinpainted suffix + .where_reinpainted sidecar
export INPUT_EXTENSION=".uvh5"
export SCAFFOLD_EXTENSION=".uvh5"
export OUTPUT_EXTENSION=".reinpainted.uvh5"
export WHERE_INPAINTED_EXTENSION=".where_reinpainted.h5"

# Execute notebook
nb_outfile="${cross_file%.uvh5}.single_lststack_baseline_reinpaint.html"
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/single_baseline_scaffolded_and_feathered_inpainter.ipynb
echo "Finished LST-stack single-baseline re-inpainting notebook at $(date)"

# Verify outputs
out_uvh5="${cross_file%.uvh5}.reinpainted.uvh5"
out_where="${cross_file%.uvh5}.where_reinpainted.h5"
if [ ! -f "${out_uvh5}" ]; then
    echo "Expected re-inpainted output ${out_uvh5} not produced." >&2
    exit 1
fi
if [ ! -f "${out_where}" ]; then
    echo "Expected where_reinpainted sidecar ${out_where} not produced." >&2
    exit 1
fi
echo "Resulting ${out_uvh5} and ${out_where} found."

# Symlink HTML into nb_output_repo
if [ -f "${nb_outfile}" ]; then
    nb_dest_dir="${nb_output_repo}/single_lststack_baseline_reinpaint"
    mkdir -p "${nb_dest_dir}"
    ln -sf "$(realpath "${nb_outfile}")" "${nb_dest_dir}/$(basename "${nb_outfile}")"
    nb_index_script="${src_dir}/../../analysis/task_scripts/build_notebook_index.py"
    python "${nb_index_script}" "${nb_dest_dir}"
fi
