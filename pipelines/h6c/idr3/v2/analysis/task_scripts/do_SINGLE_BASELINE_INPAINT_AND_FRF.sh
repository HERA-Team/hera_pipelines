#! /bin/bash
set -e

# This loads a single baseline (all pols) for all times and performs 2D-informed inpainting and FR=0 filtering on the data.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
FM_low_freq=${4}
FM_high_freq=${5}
auto_inpaint_delay=${6}
inpaint_delay=${7}
iterative_delay_delta=${8}
eigenval_cutoff=${9}
cg_tol=${10}
inpaint_width_factor=${11}
inpaint_zero_dist_weight=${12}
auto_fr_spectrum_file=${13}
gauss_fit_buffer_cut=${14}
fr0_filter=${15}
fr0_halfwidth=${16}

# path manipulation
jd=$(get_int_jd ${fn})
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export RED_AVG_FILE=${SUM_FILE%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
export CORNER_TURN_MAP_YAML="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/corner_turn_map.yaml"
export R3_FLAG_FILE="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/zen.${jd}.flag_waterfall_round_3.h5"

# other settings
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export AUTO_INPAINT_DELAY=${auto_inpaint_delay}
export INPAINT_DELAY=${inpaint_delay}
export ITERATIVE_DELAY_DELTA=${iterative_delay_delta}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export CG_TOL=${cg_tol}
export INPAINT_WIDTH_FACTOR=${inpaint_width_factor}
export INPAINT_ZERO_DIST_WEIGHT=${inpaint_zero_dist_weight}
export AUTO_FR_SPECTRUM_FILE=${auto_fr_spectrum_file}
export GAUSS_FIT_BUFFER_CUT=${gauss_fit_buffer_cut}
export FR0_FILTER=${fr0_filter}
export FR0_HALFWIDTH=${fr0_halfwidth}
export INPAINTED_EXTENSION=".inpainted.uvh5"
export WHERE_INPAINTED_EXTENSION=".where_inpainted.h5"
export FR0_FILTER_EXTENSION=".inpainted.FR0_filtered.uvh5"

# produce a string like "0_0" for a single baselinea and "0_0.0_1.0_2" for multiple baselines
antpairs_str=$(python -c "
import yaml
with open('${CORNER_TURN_MAP_YAML}', 'r') as file:
    corner_turn_map = yaml.unsafe_load(file)

antpairs = corner_turn_map['files_to_antpairs_map']['${RED_AVG_FILE}']
ubl_keys = [corner_turn_map['antpairs_to_ubl_keys_map'][ap] for ap in antpairs]
if len(ubl_keys) > 0:
    print('.'.join(['_'.join(str(ant) for ant in ap) for ap in ubl_keys]))
else:
    print('none')
")

if [ "$antpairs_str" = "none" ]; then
    echo "No antpairs match this input file. Exiting..."
    exit 0
fi
nb_outfile="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/zen.${jd}.baseline.${antpairs_str}.sum.single_baseline_2D_informed_inpaint.html"

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/single_baseline_2D_informed_inpaint.ipynb
echo Finished running 2D informed inpainting notebook at $(date)

# check if "0_4" is in the antpairs_str, if so copy the notebook to the output repo
if [[ ".${antpairs_str}." == *".0_4."* ]]; then
    # Copy file to github repo
    cp ${nb_outfile} ${nb_output_repo}/single_baseline_2D_informed_inpaint/single_baseline_2D_informed_inpaint_${jd}.html
    python ${src_dir}/build_notebook_index.py ${nb_output_repo}/single_baseline_2D_informed_inpaint
fi
