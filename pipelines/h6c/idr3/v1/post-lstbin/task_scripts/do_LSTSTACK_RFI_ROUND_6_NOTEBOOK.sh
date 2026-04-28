#! /bin/bash
set -e

# Aggregates per-baseline LST-stack pI_FRF_SNR outputs, rephases coherently to bright
# sources, computes an incoherent |SNR| average, applies z-score-based RFI flagging,
# and writes per-source + incoherent flag waterfalls (Round 6).

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters from the configuration file
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

outdir=$(cd "$(dirname "$fn")" && pwd)

# Notebook env vars
export SINGLE_BL_DIR="${outdir}"
export SNR_SUFFIX=".sum.pI_FRF_SNR.uvh5"
export OUTFILE_SUFFIX=".flag_waterfall_round_6.h5"
export MIN_SAMP_FRAC=${min_samp_frac}
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export Z_THRESH=${z_thresh}
export WS_Z_THRESH=${ws_z_thresh}
export AVG_Z_THRESH=${avg_z_thresh}
export MAX_FREQ_FLAG_FRAC=${max_freq_flag_frac}
export MAX_TIME_FLAG_FRAC=${max_time_flag_frac}
export TIME_CONV_SIZE=${time_conv_size}

# Output HTML lives directly in the nb_output_repo subfolder (one notebook per LST run)
nb_outdir=${nb_output_repo}/full_lststack_rfi_round_6
mkdir -p "${nb_outdir}"
nb_outfile="${nb_outdir}/full_lststack_rfi_round_6.html"

jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/full_lststack_rfi_round_6.ipynb
echo "Finished LST-stack RFI Round 6 notebook at $(date)"

# Verify at least one round-6 flag waterfall was produced
n_outfiles=$(ls ${outdir}/zen.LST.*.flag_waterfall_round_6.h5 2>/dev/null | wc -l)
if [ "${n_outfiles}" -gt 0 ]; then
    echo "Found ${n_outfiles} Round 6 flag waterfall file(s) in ${outdir}."
else
    echo "No Round 6 flag waterfall files found in ${outdir}." >&2
    exit 1
fi

# Rebuild notebook index for this section
python ${src_dir}/../../analysis/task_scripts/build_notebook_index.py "${nb_outdir}"
