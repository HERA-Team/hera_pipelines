#! /bin/bash
set -e

# This script generates an HTML version of a notebook which performs fourth-round full-day RFI flagging
# based on delay-filtered pI SNRs coherently rephased to known bright sources.

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
min_samp_frac=${4}
FM_low_freq=${5}
FM_high_freq=${6}
z_thresh=${7}
ws_z_thresh=${8}
avg_z_thresh=${9}
max_freq_flag_frac=${10}
max_time_flag_frac=${11}
time_conv_size=${12}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/full_day_rfi_round_4
nb_outfile=${nb_outdir}/full_day_rfi_round_4_${jd}.html

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export RED_AVG_FILE=${SUM_FILE%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
export CORNER_TURN_MAP_YAML="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/corner_turn_map.yaml"
export SNR_SUFFIX=".inpainted.pI_DLYFILT_SNR.uvh5"
export MIN_SAMP_FRAC=${min_samp_frac}
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export Z_THRESH=${z_thresh}
export WS_Z_THRESH=${ws_z_thresh}
export AVG_Z_THRESH=${avg_z_thresh}
export MAX_FREQ_FLAG_FRAC=${max_freq_flag_frac}
export MAX_TIME_FLAG_FRAC=${max_time_flag_frac}
export TIME_CONV_SIZE=${time_conv_size}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/full_day_rfi_round_4.ipynb
echo Finished full-day rfi round 4 notebook at $(date)

# Check to see that at least one per-source flag waterfall was produced
outfile_dir="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files"
n_outfiles=$(ls ${outfile_dir}/zen.${jd}.*.flag_waterfall_round_4.h5 2>/dev/null | wc -l)
if [ "${n_outfiles}" -gt 0 ]; then
    echo Found ${n_outfiles} round 4 flag waterfall file\(s\) in ${outfile_dir}.
else
    echo No round 4 flag waterfall files found in ${outfile_dir}.
    exit 1
fi

python ${src_dir}/build_notebook_index.py ${nb_outdir}
