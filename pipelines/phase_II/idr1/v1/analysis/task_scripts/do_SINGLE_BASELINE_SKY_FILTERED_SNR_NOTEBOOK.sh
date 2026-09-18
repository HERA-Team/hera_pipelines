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

# What the corner-turn map assigns to this file: nothing to do without cross-correlations, and the night's
# rendered notebook is published by whichever job handles the first cross-correlation group
map_path="$(dirname ${SUM_FILE})/$(get_filename ${toml_file} CORNER_TURN_MAP)"
red_avg_file=$(swap_suffix ${SUM_FILE} ${toml_file} RED_AVG)
assignment=$(python - "${map_path}" "${red_avg_file}" <<'PYEOF'
import sys, yaml
with open(sys.argv[1]) as f:
    corner_turn_map = yaml.unsafe_load(f)
ubl_key = corner_turn_map['antpairs_to_ubl_keys_map']
crosses = lambda antpairs: sorted({tuple(ubl_key[ap]) for ap in antpairs if ubl_key[ap][0] != ubl_key[ap][1]})
mine = crosses(corner_turn_map['files_to_antpairs_map'].get(sys.argv[2], []))
first = min(key for antpairs in corner_turn_map['files_to_antpairs_map'].values() for key in crosses(antpairs))
print('none' if len(mine) == 0 else ('publish' if first in mine else 'run'))
PYEOF
)
if [ "${assignment}" == "none" ]; then
    echo "The corner-turn map assigns no cross-correlations to ${fn}. Exiting..."
    exit 0
fi

# Execute notebook
nb_outfile=${SUM_FILE%.uvh5}.sky_filtered_SNR_notebook.html
jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/single_baseline_sky_filtered_SNR.ipynb
echo Finished running single-baseline sky-filtered SNR notebook at $(date)

# Baselines with too few samples legitimately get no SNR file, so there is no output to insist on here:
# a failed notebook has already stopped this script
if [ "${assignment}" == "publish" ]; then
    jd=$(get_int_jd ${fn})
    nb_dest_dir=${nb_output_repo}/single_baseline_sky_filtered_SNR
    nb_dest_file=${nb_dest_dir}/single_baseline_sky_filtered_SNR_${jd}.html
    mkdir -p ${nb_dest_dir}
    cp ${nb_outfile} ${nb_dest_file}
    python ${src_dir}/build_notebook_index.py ${nb_dest_dir}
fi
