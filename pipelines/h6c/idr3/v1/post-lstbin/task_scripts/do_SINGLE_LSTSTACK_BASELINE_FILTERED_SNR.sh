#! /bin/bash
set -e

# This loads one LST-stacked single-baseline cross file (and a sibling auto file), forms
# pseudo-Stokes pI, and computes delay-filtered + fringe-rate-filtered SNR waterfalls.
# Calls the (adapted) single_baseline_pI_FRF_SNR.ipynb in LSTSTACK_MODE so the notebook
# itself handles single-file / no-corner_turn_map / no-.inpainted-suffix logic.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters from the configuration file
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
FM_low_freq=${4}
FM_high_freq=${5}
filter_delay=${6}
eigenval_cutoff=${7}
fr_spectra_file=${8}
auto_fr_spectrum_file=${9}
xtalk_fr=${10}
fr_quantile_low=${11}
fr_quantile_high=${12}
min_samp_frac=${13}
skip_fr0_overlap_baselines=${14}

# Path manipulation
outdir=$(cd "$(dirname "$fn")" && pwd)
cross_file="${outdir}/$(basename "$fn")"

echo "Performing LST-stack single-baseline filtered-SNR computation on ${cross_file}"

# Skip autocorrelations or if any polarization is fully flagged
if ! python ${src_dir}/check_single_bl_file.py ${cross_file} --skip_autos; then
    echo "Skipping ${cross_file} (it's an autocorrelation or a fully-flagged polarization)."
    exit 0
fi

# Mode + single-file IO interface (consumed by the LSTSTACK_MODE branch in the notebook)
export LSTSTACK_MODE="TRUE"
export RED_AVG_FILE="${cross_file}"

# Filter and FR knobs
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export FILTER_DELAY=${filter_delay}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export FR_SPECTRA_FILE=${fr_spectra_file}
export AUTO_FR_SPECTRUM_FILE=${auto_fr_spectrum_file}
export XTALK_FR=${xtalk_fr}
export FR_QUANTILE_LOW=${fr_quantile_low}
export FR_QUANTILE_HIGH=${fr_quantile_high}
export MIN_SAMP_FRAC=${min_samp_frac}
export SAVE_DLY_SNR="FALSE"
export SAVE_FRF_SNR="TRUE"
export FRF_SNR_SUFFIX=".pI_FRF_SNR.uvh5"
export APPLY_PRIOR_FLAGS="FALSE"
export APPLY_WHERE_INPAINTED_FLAGS="FALSE"
export SKIP_FR0_OVERLAP_BASELINES=${skip_fr0_overlap_baselines}

# Execute notebook
nb_outfile="${cross_file%.uvh5}.single_lststack_baseline_pI_FRF_SNR.html"
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/single_baseline_pI_FRF_SNR.ipynb
echo "Finished running LST-stack single-baseline filtered-SNR notebook at $(date)"

# (Intentionally no output-existence check: the notebook may legitimately produce no SNR
#  file for baselines that are too sparsely sampled, etc.)

# Symlink HTML into nb_output_repo
if [ -f "${nb_outfile}" ]; then
    nb_dest_dir="${nb_output_repo}/single_lststack_baseline_pI_FRF_SNR"
    mkdir -p "${nb_dest_dir}"
    ln -sf "$(realpath "${nb_outfile}")" "${nb_dest_dir}/$(basename "${nb_outfile}")"
    nb_index_script="${src_dir}/../../analysis/task_scripts/build_notebook_index.py"
    python "${nb_index_script}" "${nb_dest_dir}"
fi
