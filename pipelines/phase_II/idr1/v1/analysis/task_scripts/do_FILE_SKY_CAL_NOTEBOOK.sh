#! /bin/bash
set -e

# Runs file_sky_calibration.ipynb on a single raw sum file. The notebook reads its
# configuration from the [GLOBAL_OPTS], [FILE_SKY_CAL_OPTS], and [ANT_CLASS_BOUNDS]
# sections of the toml directly via toml.load(TOML_FILE), so this script passes only paths.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [FILE_SKY_CAL_NOTEBOOK])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

# Env vars consumed by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export TOML_FILE=${toml_file}

# Execute notebook
nb_outfile=${SUM_FILE%.uvh5}.sky_calibration_notebook.html
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/file_sky_calibration.ipynb
echo Finished running file sky calibration notebook at $(date)

# All four outputs are always produced (as fully-flagged placeholders if necessary),
# so any absence is an error.
antclass_file=$(swap_suffix ${SUM_FILE} ${toml_file} ANT_CLASS)
sky_cal_file=$(swap_suffix ${SUM_FILE} ${toml_file} SKY_CAL)
decoherence_file=$(swap_suffix ${SUM_FILE} ${toml_file} DECOHERENCE)
red_avg_zscore_file=$(swap_suffix ${SUM_FILE} ${toml_file} RED_AVG_ZSCORE)
for f in ${antclass_file} ${sky_cal_file} ${decoherence_file} ${red_avg_zscore_file}; do
    if [ -f "$f" ]; then
        echo Resulting $f found.
    else
        echo $f not produced.
        exit 1
    fi
done

# Get JD from filename
jd=$(get_int_jd ${fn})
sum_suffix=$(get_suffix ${toml_file} SUM)
is_middle_file=`python -c "import glob; files=sorted(glob.glob('zen.*${jd}*.${sum_suffix}')); print('${fn}' == files[len(files) // 2])"`
if [ "${is_middle_file}" == "True" ]; then
    # Copy the night's middle file's rendered notebook to the output directory
    nb_dest_dir=${nb_output_repo}/file_sky_calibration
    nb_dest_file=${nb_dest_dir}/file_sky_calibration_${jd}.html
    mkdir -p ${nb_dest_dir}
    cp ${nb_outfile} ${nb_dest_file}
    python ${src_dir}/build_notebook_index.py ${nb_dest_dir}
fi
