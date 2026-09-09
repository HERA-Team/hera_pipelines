#! /bin/bash
set -e

# PLACEHOLDER: flag on fringe-rate-filtered pI SNRs (H6C full_day_rfi_round_5, Josh Dillon and Tyler Cox).
# Not yet implemented -- this script deliberately does nothing (and succeeds) so the workflow runs
# end to end while the stage is designed. Positional args match phase_II_analysis.toml [FULL_DAY_RFI_PI_FRF_NOTEBOOK].

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}
nb_dest_dir=${nb_output_repo}/full_day_rfi_pI_FRF  # where the rendered notebooks will be published

echo "${ACTION} is a placeholder and does nothing yet (called on ${fn})."
