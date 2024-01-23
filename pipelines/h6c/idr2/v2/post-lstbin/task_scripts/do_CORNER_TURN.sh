#! /bin/bash
set -e

# This loads a single baseline (both pols) for all times and writes it as its own file.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

fn=${1}
out_folder=$(dirname "$fn")/single_baseline_files
file_glob=`echo $(dirname "$fn")'/zen.LST.*'`

echo python ${src_dir}/corner_turn.py ${fn} ${file_glob} ${out_folder}
python ${src_dir}/corner_turn.py ${fn} ${file_glob} ${out_folder}
