#! /bin/bash
set -e

# PLACEHOLDER: fit polarized point sources (position + rotation measure) and build Faraday-rotating DPSS models to subtract (H6C IDR3.2 per_night_source_filtering_notebook, Tyler Cox).
# Not yet implemented -- this script deliberately does nothing (and succeeds) so the workflow runs
# end to end while the stage is designed. Positional args match phase_II_analysis.toml [PER_NIGHT_SOURCE_FILTERING_NOTEBOOK].

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}
nb_dest_dir=${nb_output_repo}/per_night_source_filtering  # where the rendered notebooks will be published

echo "${ACTION} is a placeholder and does nothing yet (called on ${fn})."
