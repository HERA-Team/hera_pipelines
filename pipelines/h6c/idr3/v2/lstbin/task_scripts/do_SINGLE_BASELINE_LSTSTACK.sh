#! /bin/bash
set -euo pipefail

# This script runs the single baseline LST stacking notebook. The selection
# decision is made HERE, not in baseline_map.yaml: the YAML carries raw facts
# (bl_length_m, avg_redundancy) and this script thresholds them against TOML
# parameters, so the TOML can be edited to re-scope the run without
# regenerating the YAML.
#
# TOML parameters (both optional, under [LST_STACK_OPTS]):
#   MAX_BL_LENGTH          -- run only if bl_length_m <= this (meters)
#   MIN_AVG_REDUNDANCY     -- run only if avg_redundancy  >= this
# Missing keys mean "don't filter on that axis".

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

bl_str=${1}
toml_file=${2}

# read relevant variables from TOML
{
    IFS= read -r nb_template_dir
    IFS= read -r nb_output_repo
    IFS= read -r OUTDIR
    IFS= read -r MAX_BL_LENGTH
    IFS= read -r MIN_AVG_REDUNDANCY
} < <(
    python3 -c 'import toml
d = toml.load("'"$toml_file"'")
opts = d["LST_STACK_OPTS"]
print(d["NOTEBOOK_OPTS"]["nb_template_dir"])
print(d["NOTEBOOK_OPTS"]["nb_output_repo"])
print(opts["OUTDIR"])
print(opts.get("MAX_BL_LENGTH", ""))
print(opts.get("MIN_AVG_REDUNDANCY", ""))'
)

yaml_path="${OUTDIR}/baseline_map.yaml"

# pull raw facts from the YAML
bl_length_m=$(python3 "${src_dir}/query_baseline_map.py" "${yaml_path}" "${bl_str}" bl_length_m)
avg_redundancy=$(python3 "${src_dir}/query_baseline_map.py" "${yaml_path}" "${bl_str}" avg_redundancy)

# threshold against TOML parameters
should_run=$(python3 -c '
import sys
bl_length_m   = float(sys.argv[1])
avg_red       = float(sys.argv[2])
max_bl_length = sys.argv[3]
min_avg_red   = sys.argv[4]
ok = True
if max_bl_length and bl_length_m > float(max_bl_length):
    ok = False
if min_avg_red and avg_red < float(min_avg_red):
    ok = False
print("True" if ok else "False")
' "${bl_length_m}" "${avg_redundancy}" "${MAX_BL_LENGTH}" "${MIN_AVG_REDUNDANCY}")

if [ "${should_run}" != "True" ]; then
    echo "Baseline ${bl_str} deferred (bl_length_m=${bl_length_m}, avg_redundancy=${avg_redundancy}; MAX_BL_LENGTH=${MAX_BL_LENGTH:-none}, MIN_AVG_REDUNDANCY=${MIN_AVG_REDUNDANCY:-none}). Adjust thresholds in the TOML to run this baseline."
    exit 1
fi

# export necessary environment variables to be read by notebook
export TOML_FILE=${toml_file}
export BASELINE_STRING=${bl_str}
echo Now running baseline ${BASELINE_STRING} with settings specified in ${TOML_FILE}

# Execute jupyter notebook
nb_outfile="${OUTDIR}/baseline.${BASELINE_STRING}.lst_stack_and_reinpaint.html"
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/single_baseline_lst_stack_and_reinpaint.ipynb
echo Finished running single-baseline LST-stacking and re-inpainting notebook at $(date)

# Create symlink in notebook repo for web viewing
nb_dest_dir="${nb_output_repo}/lststack"
mkdir -p "${nb_dest_dir}"
ln -sf "$(realpath "${nb_outfile}")" "${nb_dest_dir}/$(basename "${nb_outfile}")"

# Rebuild notebook index
nb_index_script="${src_dir}/../../analysis/task_scripts/build_notebook_index.py"
python "${nb_index_script}" "${nb_dest_dir}"
