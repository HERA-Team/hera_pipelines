#! /bin/bash
set -e

# This script runs the single night LST-Cal notebook

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

bl_str=${1}
toml_file=${2}

# If Python exits 0, jd gets the printed value; else the 'else' branch runs.
if jd="$(python3 "${src_dir}/is_baseline_in_jd_map.py" "$bl_str" "$toml_file")"; then
  echo "Baseline $bl_str maps to JD $jd — proceeding..."
  # ... do calibration work using "$jd" ...
else
  echo "Baseline $bl_str does not map to a JD. Exiting..."
  exit 0
fi

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

# # export necessary environment variables to be read by notebook
export TOML_FILE=${toml_file}
export BASELINE_STRING=${bl_str}
echo Now running LST-cal on night ${jd} with settings specified in ${TOML_FILE}

# # Execute jupyter notebook
nb_outfile="${OUTDIR}/zen.${jd}.single_night_lstcal.html"
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/single_night_lstcal.ipynb
echo Finished running single-night LST-calibration notebook at $(date)

# if baseline string is "0_0", copy notebook for easy viewing
if [[ ${BASELINE_STRING} == "0_0" ]]; then
    cp ${nb_outfile} ${nb_output_repo}/lststack/
fi
