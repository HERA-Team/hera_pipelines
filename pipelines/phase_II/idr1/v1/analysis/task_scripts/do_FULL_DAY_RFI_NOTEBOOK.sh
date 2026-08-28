#! /bin/bash
set -e

# Runs full_day_rfi.ipynb once per day (on the day's first file, with every
# FILE_SKY_CAL_NOTEBOOK job as a prereq), synthesizing the night's per-file z-scores into
# full-day RFI flags. The notebook reads its configuration from the [FULL_DAY_RFI_OPTS] and
# [DATA_PRODUCTS] sections of the toml directly via toml.load(TOML_FILE), so this script
# passes only paths.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [FULL_DAY_RFI_NOTEBOOK])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

# Env vars consumed by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export TOML_FILE=${toml_file}

# Execute the notebook, rendering straight into the output repository (one file per day)
jd=$(get_int_jd ${fn})
nb_dest_dir=${nb_output_repo}/full_day_rfi
nb_outfile=${nb_dest_dir}/full_day_rfi_${jd}.html
mkdir -p ${nb_dest_dir}
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/full_day_rfi.ipynb
echo Finished running full-day RFI notebook at $(date)
python ${src_dir}/build_notebook_index.py ${nb_dest_dir}

# every red_avg_zscore must now have a matching flag_waterfall
n_zscore=$(ls zen.*.sum.red_avg_zscore.h5 2>/dev/null | wc -l)
n_flags=$(ls zen.*.sum.flag_waterfall.h5 2>/dev/null | wc -l)
if [ "${n_flags}" -ne "${n_zscore}" ] || [ "${n_zscore}" -eq 0 ]; then
    echo Found ${n_flags} flag_waterfall.h5 files for ${n_zscore} red_avg_zscore.h5 files.
    exit 1
fi
echo Found matching flag_waterfall.h5 files for all ${n_zscore} red_avg_zscore.h5 files.
