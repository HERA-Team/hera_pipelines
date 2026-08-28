#! /bin/bash
set -e

# Runs full_day_antenna_flagging.ipynb once per day (on the day's first file, with every
# FILE_SKY_CAL_NOTEBOOK job as a prereq), harmonizing per-antenna flags across the night.
# The notebook reads its configuration from the [FULL_DAY_ANT_FLAG_OPTS] and
# [ANT_CLASS_BOUNDS] sections of the toml directly via toml.load(TOML_FILE), so this
# script passes only paths.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [FULL_DAY_ANTENNA_FLAGGING_NOTEBOOK])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

# Env vars consumed by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export TOML_FILE=${toml_file}

# Execute the notebook, rendering straight into the output repository (one file per day)
jd=$(get_int_jd ${fn})
nb_dest_dir=${nb_output_repo}/full_day_antenna_flagging
nb_outfile=${nb_dest_dir}/full_day_antenna_flagging_${jd}.html
mkdir -p ${nb_dest_dir}
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/full_day_antenna_flagging.ipynb
echo Finished running full-day antenna flagging notebook at $(date)
python ${src_dir}/build_notebook_index.py ${nb_dest_dir}

# every sky.calfits must now have a matching antenna_flags.h5
n_cal=$(ls zen.*.$(get_suffix ${toml_file} SKY_CAL) 2>/dev/null | wc -l)
n_flags=$(ls zen.*.$(get_suffix ${toml_file} ANTENNA_FLAGS) 2>/dev/null | wc -l)
if [ "${n_cal}" -ne "${n_flags}" ] || [ "${n_cal}" -eq 0 ]; then
    echo Found ${n_flags} antenna_flags.h5 files for ${n_cal} sky.calfits files.
    exit 1
fi
echo Found matching antenna_flags.h5 files for all ${n_cal} sky.calfits files.
