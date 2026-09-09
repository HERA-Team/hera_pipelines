#! /bin/bash
set -e

# Runs file_redundant_averaging.ipynb on a single raw sum file, once the night's
# calibration_smoothing has finished. The notebook reads its configuration from the
# [GLOBAL_OPTS], [FILE_RED_AVG_OPTS], and [DATA_PRODUCTS] sections of the toml directly via
# toml.load(TOML_FILE), so this script passes only paths.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [FILE_RED_AVG_NOTEBOOK])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

# Env vars consumed by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export TOML_FILE=${toml_file}

# Execute notebook
nb_outfile=${SUM_FILE%.uvh5}.redundant_averaging_notebook.html
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/file_redundant_averaging.ipynb
echo Finished running file redundant averaging notebook at $(date)

# The output is always produced (fully flagged if necessary), so its absence is an error.
red_avg_file=$(swap_suffix ${SUM_FILE} ${toml_file} RED_AVG)
if [ -f "${red_avg_file}" ]; then
    echo Resulting ${red_avg_file} found.
else
    echo ${red_avg_file} not produced.
    exit 1
fi

# Get JD from filename
jd=$(get_int_jd ${fn})
sum_suffix=$(get_suffix ${toml_file} SUM)
is_middle_file=`python -c "import glob; files=sorted(glob.glob('zen.*${jd}*.${sum_suffix}')); print('${fn}' == files[len(files) // 2])"`
if [ "${is_middle_file}" == "True" ]; then
    # Copy the night's middle file's rendered notebook to the output directory
    nb_dest_dir=${nb_output_repo}/file_redundant_averaging
    nb_dest_file=${nb_dest_dir}/file_redundant_averaging_${jd}.html
    mkdir -p ${nb_dest_dir}
    cp ${nb_outfile} ${nb_dest_file}
    python ${src_dir}/build_notebook_index.py ${nb_dest_dir}
fi
