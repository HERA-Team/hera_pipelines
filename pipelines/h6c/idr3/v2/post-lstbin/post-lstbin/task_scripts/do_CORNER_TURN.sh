#! /bin/bash
set -e

# This loads a single baseline (both pols) for all times and writes it as its own file.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

fn=${1}
out_folder="single_baseline_files"

echo python ${src_dir}/corner_turn.py ${fn} ${out_folder}
python ${src_dir}/corner_turn.py ${fn} ${out_folder}
