#! /bin/bash
set -e

# This script generates an HTML version of a notebook which performs second-round full-day RFI flagging based on delay-filtered z-scores.
# It also zips up resultant UVFlag files and adds them to the librarian

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
z_thresh=${4}
ws_z_thresh=${5}
avg_z_thresh=${6}
max_freq_flag_frac=${7}
max_time_flag_frac=${8}
avg_spectrum_filter_delay=${9}
eigenval_cutoff=${10}
time_avg_delay_filt_snr_thresh=${11}
time_avg_delay_filt_snr_dynamic_range=${12}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/full_day_rfi_round_2
nb_outfile=${nb_outdir}/full_day_rfi_round_2_${jd}.html

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export SUM_SUFFIX="sum.uvh5"
export SMOOTH_CAL_SUFFIX="sum.smooth.calfits"
export ZSCORE_SUFFIX="sum.red_avg_zscore.h5"
export FLAG_WATERFALL2_SUFFIX="sum.flag_waterfall_round_2.h5"
export OUT_YAML_SUFFIX="_aposteriori_flags.yaml"
export Z_THRESH=${z_thresh}
export WS_Z_THRESH=${ws_z_thresh}
export AVG_Z_THRESH=${avg_z_thresh}
export MAX_FREQ_FLAG_FRAC=${max_freq_flag_frac}
export MAX_TIME_FLAG_FRAC=${max_time_flag_frac}
export AVG_SPECTRUM_FILTER_DELAY=${avg_spectrum_filter_delay}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export TIME_AVG_DELAY_FILT_SNR_THRESH=${time_avg_delay_filt_snr_thresh}
export TIME_AVG_DELAY_FILT_SNR_DYNAMIC_RANGE=${time_avg_delay_filt_snr_dynamic_range}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/full_day_rfi_round_2.ipynb
echo Finished full-day rfi round 2 notebook at $(date)

# Check to see that at least one output file was correctly produced
first_outfile=${SUM_FILE%.sum.uvh5}.sum.flag_waterfall_round_2.h5
if [ -f "$first_outfile" ]; then
    echo Resulting $first_outfile found.
else
    echo $first_outfile not produced.
    exit 1
fi
