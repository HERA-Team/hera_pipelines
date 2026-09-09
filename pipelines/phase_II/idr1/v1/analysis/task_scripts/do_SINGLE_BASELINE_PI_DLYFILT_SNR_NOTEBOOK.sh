#! /bin/bash
set -e

# PLACEHOLDER: delay-filtered pseudo-Stokes I SNRs, coherently rephased to bright sources (H6C single_baseline_pI_snr without FRF, Josh Dillon and Tyler Cox).
# Not yet implemented -- this script deliberately does nothing (and succeeds) so the workflow runs
# end to end while the stage is designed. Positional args match phase_II_analysis.toml [SINGLE_BASELINE_PI_DLYFILT_SNR_NOTEBOOK].

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}
nb_dest_dir=${nb_output_repo}/single_baseline_pI_dlyfilt_SNR  # where the rendered notebooks will be published

echo "${ACTION} is a placeholder and does nothing yet (called on ${fn})."
