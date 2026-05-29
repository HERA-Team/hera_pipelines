#! /bin/bash
set -e

# This script generates an HTML version of a notebook which fits polarized point source models
# (position + rotation measure) from per-night HERA single-baseline inpainted data, then
# builds Faraday-rotating DPSS models suitable for subtracting those sources from the visibilities.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1  - (raw) filename
# 2  - nb_template_dir: where to look for the notebook template
# 3  - nb_output_repo: repository for saving evaluated notebooks
# 4  - source_yaml: path to YAML file listing polarized point sources
# 5  - FM_low_freq: lower edge of FM band (MHz)
# 6  - FM_high_freq: upper edge of FM band (MHz)
# 7  - eigenval_cutoff: DPSS eigenvalue threshold
# 8  - fg_delay_half_width: foreground delay filter half-width (seconds)
# 9  - model_delay_half_width: source model delay half-width (seconds)
# 10 - model_frate_half_width: source model fringe-rate half-width (mHz)
# 11 - max_workers: number of parallel worker processes for file loading
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
source_yaml=${4}
FM_low_freq=${5}
FM_high_freq=${6}
eigenval_cutoff=${7}
fg_delay_half_width=${8}
model_delay_half_width=${9}
model_frate_half_width=${10}
max_workers=${11}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/per_night_source_filtering
nb_outfile=${nb_outdir}/per_night_source_filtering_${jd}.html

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export RED_AVG_FILE=${SUM_FILE%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
export CORNER_TURN_MAP_YAML="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/corner_turn_map.yaml"
export PRIOR_FLAG_SUFFIX=".flag_waterfall_round_3.h5"
export SOURCE_YAML=${source_yaml}
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export FG_DELAY_HALF_WIDTH=${fg_delay_half_width}
export MODEL_DELAY_HALF_WIDTH=${model_delay_half_width}
export MODEL_FRATE_HALF_WIDTH=${model_frate_half_width}
export MAX_WORKERS=${max_workers}
export SAVE_MODELS=TRUE

# Execute jupyter notebook and save as HTML
mkdir -p ${nb_outdir}
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/per_night_source_filtering_notebook.ipynb
echo Finished per-night source filtering notebook at $(date)

python ${src_dir}/build_notebook_index.py ${nb_outdir}
