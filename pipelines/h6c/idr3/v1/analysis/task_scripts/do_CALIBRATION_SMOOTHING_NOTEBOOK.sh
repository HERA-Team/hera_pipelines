#! /bin/bash
set -e

# This script generates an HTML version of a notebook which performs calibration smoothing.
# It also zips up resultant calfits files and adds them to the librarian, if desired.

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
freq_smoothing_scale=${4}
time_smoothing_scale=${5}
eigenval_cutoff=${6}
calibrate_cross_pols=${7}
blacklist_timescale_factor=${8}
blacklist_relative_error_thresh=${9}
blacklist_relative_weight=${10}
FM_low_freq=${11}
FM_high_freq=${12}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/calibration_smoothing
nb_outfile=${nb_outdir}/calibration_smoothing_${jd}.html

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export SUM_SUFFIX="sum.uvh5"
export CAL_SUFFIX="sum.omni.calfits"
export SMOOTH_CAL_SUFFIX="sum.smooth.calfits"
export ANT_FLAG_SUFFIX="sum.antenna_flags.h5"
export RFI_FLAG_SUFFIX="sum.flag_waterfall.h5"
export FREQ_SMOOTHING_SCALE=${freq_smoothing_scale}
export TIME_SMOOTHING_SCALE=${time_smoothing_scale}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
if [ "${calibrate_cross_pols}" == "True" ]; then
    export PER_POL_REFANT="False"
else
    export PER_POL_REFANT="True"
fi
export BLACKLIST_TIMESCALE_FACTOR=${blacklist_timescale_factor}
export BLACKLIST_RELATIVE_ERROR_THRESH=${blacklist_relative_error_thresh}
export BLACKLIST_RELATIVE_WEIGHT=${blacklist_relative_weight}
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/calibration_smoothing.ipynb
echo Finished calibration smoothing notebook at $(date)

# Check to see that at least one output file was correctly produced
first_outfile=${SUM_FILE%.sum.uvh5}.sum.smooth.calfits
if [ -f "$first_outfile" ]; then
    echo Resulting $first_outfile found.
else
    echo $first_outfile not produced.
    exit 1
fi

python ${src_dir}/build_notebook_index.py ${nb_outdir}
