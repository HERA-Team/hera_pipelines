#! /bin/bash
set -e

# This script runs the single baseline LST stacking notebook

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

bl_str=${1}
toml_file=${2}

echo "I didn't run anything. I'm a placeholder!"

# TODO: update
# # read relevant variables from TOML
# {
#     IFS= read -r nb_template_dir
#     IFS= read -r nb_output_repo
#     IFS= read -r OUTDIR
# } < <(
#     python3 -c 'import toml
# d = toml.load("'"$toml_file"'")
# print(d["NOTEBOOK_OPTS"]["nb_template_dir"])
# print(d["NOTEBOOK_OPTS"]["nb_output_repo"])
# print(d["LST_STACK_OPTS"]["OUTDIR"])'
# )

# # export necessary environment variables to be read by notebook
# export TOML_FILE=${toml_file}
# export BASELINE_STRING=${bl_str}
# echo Now running baseline ${BASELINE_STRING} with settings specified in ${TOML_FILE}

# # Execute jupyter notebook
# nb_outfile="${OUTDIR}/baseline.${BASELINE_STRING}.lst_stack_and_reinpaint.html"
# jupyter nbconvert --output=${nb_outfile} \
# --to html \
# --ExecutePreprocessor.timeout=-1 \
# --execute ${nb_template_dir}/single_baseline_lst_stack_and_reinpaint.ipynb
# echo Finished running single-baseline LST-stacking and re-inpainting notebook at $(date)

# # if baseline string is "0_4", copy notebook for easy viewing
# if [[ ${BASELINE_STRING} == "0_4" ]]; then
#     cp ${nb_outfile} ${nb_output_repo}/lststack/
# fi
