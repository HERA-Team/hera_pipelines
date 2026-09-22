#! /bin/bash
set -e

# Runs per_night_source_filtering_notebook.ipynb once per night (on the night's first file, with the
# FULL_DAY_RFI_SKY_FILTERED_NOTEBOOK job as a prereq): fits polarized point sources (position + rotation
# measure) on the flagged, non-inpainted single-baseline files and writes Faraday-rotating DPSS models
# of them for subtraction before the pI SNRs are formed (H6C IDR3.2 per_night_source_filtering_notebook, Tyler Cox).

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [PER_NIGHT_SOURCE_FILTERING_NOTEBOOK])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

# Env vars consumed by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export TOML_FILE=${toml_file}

# Execute the notebook, rendering straight into the output repository (one file per night)
jd=$(get_int_jd ${fn})
nb_dest_dir=${nb_output_repo}/per_night_source_filtering
nb_outfile=${nb_dest_dir}/per_night_source_filtering_${jd}.html
mkdir -p ${nb_dest_dir}
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/per_night_source_filtering_notebook.ipynb
echo Finished running per-night source filtering notebook at $(date)
python ${src_dir}/build_notebook_index.py ${nb_dest_dir}

# at least one source model must now exist (which sources get modeled depends on the night's LST coverage)
model_pattern="$(dirname ${SUM_FILE})/$(get_filename ${toml_file} SOURCE_MODELS)"
model_pattern=${model_pattern//\{JD\}/${jd}}
model_pattern=${model_pattern//\{source\}/*}
model_pattern=${model_pattern//\{model\}/rm_model}
n_models=$(ls ${model_pattern} 2>/dev/null | wc -l)
if [ "${n_models}" -gt 0 ]; then
    echo Found ${n_models} source models matching ${model_pattern}.
else
    echo No source models matching ${model_pattern} were produced.
    exit 1
fi
