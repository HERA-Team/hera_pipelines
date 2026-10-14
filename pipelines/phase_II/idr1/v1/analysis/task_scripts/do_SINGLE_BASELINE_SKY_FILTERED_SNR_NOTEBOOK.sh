#! /bin/bash
set -e

# Runs single_baseline_sky_filtered_SNR.ipynb on the whole-night single-baseline files that the corner-turn
# map assigns to one raw sum file: a 2D DPSS filter removes everything sky-like and the residual is saved
# as an SNR for full_day_rfi_sky_filtered.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [SINGLE_BASELINE_SKY_FILTERED_SNR_NOTEBOOK])
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
baselines=$(python - "${map_path}" "${red_avg_file}" <<'PYEOF'
import sys, yaml
with open(sys.argv[1]) as f:
    corner_turn_map = yaml.unsafe_load(f)
ubl_key = corner_turn_map['antpairs_to_ubl_keys_map']
keys = [tuple(ubl_key[ap]) for ap in corner_turn_map['files_to_antpairs_map'].get(sys.argv[2], [])
        if ubl_key[ap][0] != ubl_key[ap][1]]  # skip autos
print('.'.join('_'.join(str(ant) for ant in key) for key in keys) or 'none')
PYEOF
)
if [ "${baselines}" == "none" ]; then
    echo "The corner-turn map assigns no cross-correlations to ${fn}. Exiting..."
    exit 0
fi

# Execute notebook
jd=$(get_int_jd ${fn})
nb_outfile="$(dirname ${SUM_FILE})/single_baseline_files/zen.${jd}.baseline.${baselines}.sum.sky_filtered_SNR_notebook.html"
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/single_baseline_sky_filtered_SNR.ipynb
echo Finished running single-baseline sky-filtered SNR notebook at $(date)

# Publish whichever job gets baseline 0_4
if [[ ".${baselines}." == *".0_4."* ]]; then
    nb_dest_dir=${nb_output_repo}/single_baseline_sky_filtered_SNR
    nb_dest_file=${nb_dest_dir}/single_baseline_sky_filtered_SNR_${jd}.html
    mkdir -p ${nb_dest_dir}
    cp ${nb_outfile} ${nb_dest_file}
    python ${src_dir}/build_notebook_index.py ${nb_dest_dir}
fi
