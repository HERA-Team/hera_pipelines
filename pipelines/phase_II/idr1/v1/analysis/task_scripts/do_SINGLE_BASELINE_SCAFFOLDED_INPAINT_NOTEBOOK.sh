#! /bin/bash
set -e

# PLACEHOLDER: final inpaint with the LST-stacked, 2D-DPSS-filtered model as scaffold (H6C single_baseline_scaffolded_and_feathered_inpainter, Josh Dillon and Tyler Cox).
# Not yet implemented -- this script deliberately does nothing (and succeeds) so the workflow runs
# end to end while the stage is designed. Positional args match phase_II_analysis.toml [SINGLE_BASELINE_SCAFFOLDED_INPAINT_NOTEBOOK].

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}
nb_dest_dir=${nb_output_repo}/single_baseline_scaffolded_inpaint  # where the rendered notebooks will be published

echo "${ACTION} is a placeholder and does nothing yet (called on ${fn})."
