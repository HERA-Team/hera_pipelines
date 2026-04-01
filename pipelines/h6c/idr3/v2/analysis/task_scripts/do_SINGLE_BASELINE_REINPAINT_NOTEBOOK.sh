#! /bin/bash
set -e

# This performs scaffolded, feathered 1D DPSS re-inpainting on single baseline files
# using updated flags (e.g. round 5). The scaffold is the previously-inpainted data itself.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
FM_low_freq=${4}
FM_high_freq=${5}
auto_inpaint_delay=${6}
inpaint_delay=${7}
eigenval_cutoff=${8}
cg_tol=${9}
inpaint_width_factor=${10}
inpaint_zero_dist_weight=${11}
auto_fr_spectrum_file=${12}
gauss_fit_buffer_cut=${13}

# path manipulation
jd=$(get_int_jd ${fn})
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export RED_AVG_FILE=${SUM_FILE%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
export CORNER_TURN_MAP_YAML="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/corner_turn_map.yaml"

# flag settings
export APPLY_PRIOR_FLAGS="TRUE"
export PRIOR_FLAG_SUFFIX=".flag_waterfall_round_5.h5"

# inpainting settings
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export AUTO_INPAINT_DELAY=${auto_inpaint_delay}
export INPAINT_DELAY=${inpaint_delay}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export CG_TOL=${cg_tol}
export INPAINT_WIDTH_FACTOR=${inpaint_width_factor}
export INPAINT_ZERO_DIST_WEIGHT=${inpaint_zero_dist_weight}
export AUTO_FR_SPECTRUM_FILE=${auto_fr_spectrum_file}
export GAUSS_FIT_BUFFER_CUT=${gauss_fit_buffer_cut}

# scaffold and output settings
export SCAFFOLD_EXTENSION=".inpainted.uvh5"
export INPUT_EXTENSION=".inpainted.uvh5"
export OUTPUT_EXTENSION=".reinpainted.uvh5"
export WHERE_INPAINTED_EXTENSION=".where_reinpainted.h5"

# produce a string like "0_0" for a single baseline and "0_0.0_1.0_2" for multiple baselines
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
nb_outfile="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/zen.${jd}.baseline.${antpairs_str}.sum.single_baseline_scaffolded_and_feathered_inpainter.html"

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/single_baseline_scaffolded_and_feathered_inpainter.ipynb
echo Finished running scaffolded and feathered re-inpainting notebook at $(date)

# check if "0_4" is in the antpairs_str, if so copy the notebook to the output repo
if [[ ".${antpairs_str}." == *".0_4."* ]]; then
    # Copy file to github repo
    mkdir -p ${nb_output_repo}/single_baseline_scaffolded_and_feathered_inpainter
    cp ${nb_outfile} ${nb_output_repo}/single_baseline_scaffolded_and_feathered_inpainter/single_baseline_scaffolded_and_feathered_inpainter_${jd}.html
    python ${src_dir}/build_notebook_index.py ${nb_output_repo}/single_baseline_scaffolded_and_feathered_inpainter
fi
