#! /bin/bash
set -euo pipefail

# This script runs the single night LST-Cal notebook. For each baseline the
# makeflow passes, SETUP has already decided via baseline_map.yaml which JD
# that baseline anchors (if any). Baselines with night_for_lstcal == None
# exit successfully without running the notebook.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

bl_str=${1}
toml_file=${2}

# read relevant variables from TOML
{
    IFS= read -r nb_template_dir
    IFS= read -r nb_output_repo
    IFS= read -r OUTDIR
} < <(
    python3 -c 'import toml
d = toml.load("'"$toml_file"'")
print(d["NOTEBOOK_OPTS"]["nb_template_dir"])
print(d["NOTEBOOK_OPTS"]["nb_output_repo"])
print(d["LST_STACK_OPTS"]["OUTDIR"])'
)

yaml_path="${OUTDIR}/baseline_map.yaml"

# look up which JD this baseline anchors
jd=$(python3 "${src_dir}/query_baseline_map.py" "${yaml_path}" "${bl_str}" night_for_lstcal)
if [ "${jd}" = "None" ]; then
    echo "Baseline ${bl_str} is not an lstcal anchor. Exiting..."
    exit 0
fi
echo "Baseline ${bl_str} maps to JD ${jd} — proceeding..."

# export necessary environment variables to be read by notebook
export TOML_FILE=${toml_file}
export JD=${jd}
echo Now running LST-cal on night ${jd} with settings specified in ${TOML_FILE}

# Execute jupyter notebook
nb_outfile="${OUTDIR}/zen.${jd}.single_night_lstcal.html"
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/single_night_lstcal.ipynb
echo Finished running single-night LST-calibration notebook at $(date)

# Create symlink in notebook repo for web viewing
nb_dest_dir="${nb_output_repo}/lstcal"
mkdir -p "${nb_dest_dir}"
ln -sf "$(realpath "${nb_outfile}")" "${nb_dest_dir}/$(basename "${nb_outfile}")"

# Rebuild notebook index
nb_index_script="${src_dir}/../../analysis/task_scripts/build_notebook_index.py"
python "${nb_index_script}" "${nb_dest_dir}"
