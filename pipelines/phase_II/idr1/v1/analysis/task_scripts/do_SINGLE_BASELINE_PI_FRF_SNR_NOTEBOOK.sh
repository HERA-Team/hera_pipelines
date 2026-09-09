#! /bin/bash
set -e

# PLACEHOLDER: delay + fringe-rate-filtered pI SNRs, coherent and incoherent (H6C single_baseline_pI_FRF_SNR, Josh Dillon and Tyler Cox).
# Not yet implemented -- this script deliberately does nothing (and succeeds) so the workflow runs
# end to end while the stage is designed. Positional args match phase_II_analysis.toml [SINGLE_BASELINE_PI_FRF_SNR_NOTEBOOK].

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}
nb_dest_dir=${nb_output_repo}/single_baseline_pI_FRF_SNR  # where the rendered notebooks will be published

echo "${ACTION} is a placeholder and does nothing yet (called on ${fn})."
