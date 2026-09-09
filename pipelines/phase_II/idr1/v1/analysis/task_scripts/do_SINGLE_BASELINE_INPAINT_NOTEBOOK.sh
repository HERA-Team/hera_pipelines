#! /bin/bash
set -e

# PLACEHOLDER: per-baseline DPSS inpainting with effective nsamples DPSS-filled across flag gaps (H6C single_baseline_inpaint_and_frf).
# Not yet implemented -- this script deliberately does nothing (and succeeds) so the workflow runs
# end to end while the stage is designed. Positional args match phase_II_analysis.toml [SINGLE_BASELINE_INPAINT_NOTEBOOK].

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}
nb_dest_dir=${nb_output_repo}/single_baseline_inpaint  # where the rendered notebooks will be published

echo "${ACTION} is a placeholder and does nothing yet (called on ${fn})."
