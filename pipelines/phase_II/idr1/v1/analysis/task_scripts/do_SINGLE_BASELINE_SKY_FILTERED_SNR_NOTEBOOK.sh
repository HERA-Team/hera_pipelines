#! /bin/bash
set -e

# PLACEHOLDER: per-baseline 2D DPSS filter keeping only sky-like modes (wedge + sky fringe rates) -> residual SNR (H6C single_baseline_2D_filtered_SNRs, Josh Dillon and Tyler Cox).
# Not yet implemented -- this script deliberately does nothing (and succeeds) so the workflow runs
# end to end while the stage is designed. Positional args match phase_II_analysis.toml [SINGLE_BASELINE_SKY_FILTERED_SNR_NOTEBOOK].

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}
nb_dest_dir=${nb_output_repo}/single_baseline_sky_filtered_SNR  # where the rendered notebooks will be published

echo "${ACTION} is a placeholder and does nothing yet (called on ${fn})."
