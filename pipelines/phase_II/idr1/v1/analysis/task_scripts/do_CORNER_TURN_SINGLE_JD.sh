#! /bin/bash
set -e

# PLACEHOLDER: the corner turn itself: per-file red_avg -> per-baseline, whole-night files (H6C corner_turn_single_jd.py).
# Not yet implemented -- this script deliberately does nothing (and succeeds) so the workflow runs
# end to end while the stage is designed. Positional args match phase_II_analysis.toml [CORNER_TURN_SINGLE_JD].

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}


echo "${ACTION} is a placeholder and does nothing yet (called on ${fn})."
