#! /bin/bash
set -e

# Runs calibration_smoothing.ipynb once per day (on the day's first file, after full-day RFI
# and antenna flagging), smoothing the night's sky-cal gains with day-harmonized flags and
# writing the day's complete a posteriori flag yaml. The notebook reads its configuration
# from the [GLOBAL_OPTS], [CALIBRATION_SMOOTHING_OPTS], and [DATA_PRODUCTS] sections of the
# toml directly via toml.load(TOML_FILE), so this script passes only paths.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [CALIBRATION_SMOOTHING_NOTEBOOK])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

# Env vars consumed by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export TOML_FILE=${toml_file}

# Execute the notebook, rendering straight into the output repository (one file per day)
jd=$(get_int_jd ${fn})
nb_dest_dir=${nb_output_repo}/calibration_smoothing
nb_outfile=${nb_dest_dir}/calibration_smoothing_${jd}.html
mkdir -p ${nb_dest_dir}
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/calibration_smoothing.ipynb
echo Finished running calibration smoothing notebook at $(date)
python ${src_dir}/build_notebook_index.py ${nb_dest_dir}

# every sky.calfits must now have a matching smooth.calfits, and the yaml must exist
n_cal=$(ls zen.*.sum.sky.calfits 2>/dev/null | wc -l)
n_smooth=$(ls zen.*.sum.smooth.calfits 2>/dev/null | wc -l)
if [ "${n_smooth}" -ne "${n_cal}" ] || [ "${n_cal}" -eq 0 ]; then
    echo Found ${n_smooth} smooth.calfits files for ${n_cal} sky.calfits files.
    exit 1
fi
if [ ! -f "${jd}_aposteriori_flags.yaml" ]; then
    echo ${jd}_aposteriori_flags.yaml not produced.
    exit 1
fi
echo Found matching smooth.calfits files for all ${n_cal} sky.calfits files and the a posteriori yaml.
