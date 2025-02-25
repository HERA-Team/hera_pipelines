#! /bin/bash
set -e

# This script generates an HTML version of a notebook designed to inspect the full day delay spectra 
# for a small number of redundantly-averaged baselines, by inpainting in frequency and time, and 
# performing delay filtering, cross-talk filtering, and main-beam fringe rate filtering.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4+ - various settings
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
filter_dly_min=${4}
inpaint_dly_min=${5}
inpaint_regularization=${6}
standoff=${7}
xtalk_fr=${8}
inpaint_fr=${9}
eigenval_cutoff=${10}
FM_low_freq=${11}
FM_high_freq=${12}
max_contiguous_flags=${13}
spectrum_chan_buffer=${14}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/full_day_systematics_inspect
nb_outfile=${nb_outdir}/full_day_systematics_inspect_${jd}.html

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export RED_AVG_SUFFIX="sum.smooth_calibrated.red_avg.uvh5"
export FILT_MIN_DLY=${filter_dly_min}
export INPAINT_MIN_DLY=${inpaint_dly_min}
export INPAINT_REGULARIZATION=${inpaint_regularization}
export STANDOFF=${standoff}
export XTALK_FR=${xtalk_fr}
export INPAINT_FR=${inpaint_fr}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export MAX_CONTIGUOUS_FLAGS=${max_contiguous_flags}
export SPECTRUM_CHAN_BUFFER=${spectrum_chan_buffer}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/full_day_systematics_inspect.ipynb
echo Finished full-day systematics inspect notebook at $(date)
