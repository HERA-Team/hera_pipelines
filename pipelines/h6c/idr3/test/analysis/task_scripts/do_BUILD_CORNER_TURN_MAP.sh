#! /bin/bash
set -e

# This constructs a YAML file that maps files to baselines for the purpose of performing a corner turn.

src_dir="$(dirname "$0")"

fn=${1}
sc_red_avg_file=${fn%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
out_folder="single_baseline_files"
map_yaml="corner_turn_map.yaml"

echo python ${src_dir}/build_corner_turn_map.py ${sc_red_avg_file} ${map_yaml} ${out_folder}
python ${src_dir}/build_corner_turn_map.py ${sc_red_avg_file} ${map_yaml} ${out_folder}
