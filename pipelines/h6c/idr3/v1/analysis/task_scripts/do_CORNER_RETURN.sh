#! /bin/bash
set -e

# This performs the corner re-turn, going from single baseline files back to ones that match the original, 
# redundantly averaged data in shape and file number. 

src_dir="$(dirname "$0")"

fn=${1}
fr0_filter=${2}

sc_red_avg_file=${fn%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
map_yaml_path="single_baseline_files/corner_turn_map.yaml"

# corner re-turn inpainted data
echo python ${src_dir}/corner_returner.py ${sc_red_avg_file} ${map_yaml_path} ".inpainted.uvh5"
python ${src_dir}/corner_returner.py ${sc_red_avg_file} ${map_yaml_path} ".inpainted.uvh5"

# corner re-turn where_inpainted flags
echo python ${src_dir}/corner_returner.py ${sc_red_avg_file} ${map_yaml_path} ".where_inpainted.h5"
python ${src_dir}/corner_returner.py ${sc_red_avg_file} ${map_yaml_path} ".where_inpainted.h5"

# corner re-turn FR=0 filtered data if requested
if [[ "$fr0_filter" =~ ^[Tt][Rr][Uu][Ee]$ ]]; then
    echo python ${src_dir}/corner_returner.py ${sc_red_avg_file} ${map_yaml_path} ".inpainted.FR0_filtered.uvh5"
    python ${src_dir}/corner_returner.py ${sc_red_avg_file} ${map_yaml_path} ".inpainted.FR0_filtered.uvh5"
fi
