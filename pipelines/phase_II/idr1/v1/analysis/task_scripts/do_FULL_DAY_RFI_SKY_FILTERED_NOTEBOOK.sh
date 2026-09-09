#! /bin/bash
set -e

# PLACEHOLDER: flag what is not sky-like, with special treatment of TV allocations (H6C full_day_rfi_round_3).
# Not yet implemented -- this script deliberately does nothing (and succeeds) so the workflow runs
# end to end while the stage is designed. Positional args match phase_II_analysis.toml [FULL_DAY_RFI_SKY_FILTERED_NOTEBOOK].

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}
nb_dest_dir=${nb_output_repo}/full_day_rfi_sky_filtered  # where the rendered notebooks will be published

echo "${ACTION} is a placeholder and does nothing yet (called on ${fn})."
