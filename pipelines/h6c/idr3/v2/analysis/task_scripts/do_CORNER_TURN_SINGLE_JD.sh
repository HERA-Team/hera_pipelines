#! /bin/bash
set -e

# This loads a single baseline (all pols) for all times on a single JD and writes it as its own file.

src_dir="$(dirname "$0")"

fn=${1}
sc_red_avg_file=${fn%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
out_folder="single_baseline_files"
map_yaml="corner_turn_map.yaml"

echo python ${src_dir}/corner_turn_single_jd.py ${sc_red_avg_file} ${map_yaml} ${out_folder}
python ${src_dir}/corner_turn_single_jd.py ${sc_red_avg_file} ${map_yaml} ${out_folder}
