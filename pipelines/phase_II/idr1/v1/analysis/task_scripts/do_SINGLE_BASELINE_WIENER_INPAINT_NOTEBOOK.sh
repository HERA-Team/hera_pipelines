#! /bin/bash
set -e

# Runs single_baseline_wiener_inpaint.ipynb on the whole-night single-baseline files that the corner-turn map
# assigns to one raw sum file: the final step of the per-night pipeline, inpainting them under the night's final
# flags by a 2D Wiener fill about the LST-stacked single-baseline sky model where the redundant group has one and
# about a 2D DPSS fit of the data where not (it replaces H6C's single_baseline_scaffolded_and_feathered_inpainter
# and single_baseline_2D_informed_inpaint).

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [SINGLE_BASELINE_WIENER_INPAINT_NOTEBOOK])
fn=${1}
toml_file=${2}
nb_template_dir=${3}
nb_output_repo=${4}

# Env vars consumed by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export TOML_FILE=${toml_file}

# The redundant-group keys the corner-turn map assigns to this file. They name the rendered
# notebook beside the data products it describes.
map_path="$(dirname ${SUM_FILE})/$(get_filename ${toml_file} CORNER_TURN_MAP)"
red_avg_file=$(swap_suffix ${SUM_FILE} ${toml_file} RED_AVG)
# a string like "0_4" for one group, or "0_4.1_5" for several
baselines=$(python ${src_dir}/baselines_for_file.py "${map_path}" "${red_avg_file}" --include-autos)
if [ "${baselines}" == "none" ]; then
    echo "The corner-turn map assigns no baselines to ${fn}. Exiting..."
    exit 0
fi

# Execute notebook
jd=$(get_int_jd ${fn})
nb_outfile="$(dirname ${SUM_FILE})/single_baseline_files/zen.${jd}.baseline.${baselines}.sum.wiener_inpaint_notebook.html"
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/single_baseline_wiener_inpaint.ipynb
echo Finished running single-baseline Wiener inpaint notebook at $(date)

# Publish whichever job gets baseline 0_4
if [[ ".${baselines}." == *".0_4."* ]]; then
    nb_dest_dir=${nb_output_repo}/single_baseline_wiener_inpaint
    nb_dest_file=${nb_dest_dir}/single_baseline_wiener_inpaint_${jd}.html
    mkdir -p ${nb_dest_dir}
    cp ${nb_outfile} ${nb_dest_file}
    python ${src_dir}/build_notebook_index.py ${nb_dest_dir}
fi
