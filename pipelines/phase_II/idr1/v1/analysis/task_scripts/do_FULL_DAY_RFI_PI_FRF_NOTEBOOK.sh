#! /bin/bash
set -e

# Runs full_day_rfi_pI_FRF.ipynb once per night (on the night's first file, with every
# SINGLE_BASELINE_PI_FRF_SNR_NOTEBOOK job as a prereq), combining the night's FR-filtered pI SNRs, rephased to bright sources and incoherently averaged, into the night's final flags (H6C full_day_rfi_round_5).

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [FULL_DAY_RFI_PI_FRF_NOTEBOOK])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

# Env vars consumed by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export TOML_FILE=${toml_file}

# Execute the notebook, rendering straight into the output repository (one file per night)
jd=$(get_int_jd ${fn})
nb_dest_dir=${nb_output_repo}/full_day_rfi_pI_FRF
nb_outfile=${nb_dest_dir}/full_day_rfi_pI_FRF_${jd}.html
mkdir -p ${nb_dest_dir}
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/full_day_rfi_pI_FRF.ipynb
echo Finished running full_day_rfi_pI_FRF notebook at $(date)
python ${src_dir}/build_notebook_index.py ${nb_dest_dir}

# the night's flag waterfall must now exist
flag_file="$(dirname ${SUM_FILE})/$(get_filename ${toml_file} FLAGS_PI_FRF)"
flag_file=${flag_file//\{JD\}/${jd}}
if [ -f "${flag_file}" ]; then
    echo Resulting ${flag_file} found.
else
    echo ${flag_file} not produced.
    exit 1
fi
