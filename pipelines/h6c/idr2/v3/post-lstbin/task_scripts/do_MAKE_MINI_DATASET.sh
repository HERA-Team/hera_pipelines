#! /bin/bash
set -e

# This loads a single baseline (both pols) for all times and writes it as its own file.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

fn=${1}
files_to_average=${2}
chans_to_average=${3}
ints_per_output_file=${4}
out_folder="mini_dataset"

echo python ${src_dir}/corner_turn.py ${fn} ${out_folder} --files_to_average ${files_to_average} --chans_to_average ${chans_to_average} --ints_per_output_file ${ints_per_output_file}
python ${src_dir}/corner_turn.py ${fn} ${out_folder} --files_to_average ${files_to_average} --chans_to_average ${chans_to_average} --ints_per_output_file ${ints_per_output_file}
