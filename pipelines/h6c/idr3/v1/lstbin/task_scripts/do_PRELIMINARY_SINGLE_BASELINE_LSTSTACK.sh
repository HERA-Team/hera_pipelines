#! /bin/bash
set -euo pipefail

# This script runs a preliminary single-baseline LST-stacking notebook, but
# only for the baselines that SETUP flagged as in_preliminary_set in
# baseline_map.yaml.

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

# check the frozen decision made by SETUP
use_baseline=$(python3 "${src_dir}/query_baseline_map.py" "${yaml_path}" "${bl_str}" in_preliminary_set)
if [ "${use_baseline}" != "True" ]; then
    echo "Baseline ${bl_str} is not in the preliminary set. Exiting..."
    exit 0
fi

# export necessary environment variables to be read by notebook
export TOML_FILE=${toml_file}
export BASELINE_STRING=${bl_str}
export PRELIMINARY="true"
echo Now running baseline ${BASELINE_STRING} with settings specified in ${TOML_FILE}

# Execute jupyter notebook
nb_outfile="${OUTDIR}/baseline.${BASELINE_STRING}.preliminary.lst_stack_and_reinpaint.html"
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/single_baseline_lst_stack_and_reinpaint.ipynb
echo Finished running single-baseline LST-stacking and re-inpainting notebook at $(date)

# Create symlink in notebook repo for web viewing
nb_dest_dir="${nb_output_repo}/lststack_preliminary"
mkdir -p "${nb_dest_dir}"
ln -sf "$(realpath "${nb_outfile}")" "${nb_dest_dir}/$(basename "${nb_outfile}")"

# Rebuild notebook index
nb_index_script="${src_dir}/../../analysis/task_scripts/build_notebook_index.py"
python "${nb_index_script}" "${nb_dest_dir}"
