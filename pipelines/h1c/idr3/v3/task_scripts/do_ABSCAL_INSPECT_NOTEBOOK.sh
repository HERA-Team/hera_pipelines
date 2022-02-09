#! /bin/bash
set -e

# This script generates a notebook for inspecting the results of absolute calibration calibration

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - glob-parsable string pointing to model_files
# 6+ - lst_blacklists for smooth cal
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
model_files_glob=${5}
lst_blacklists="${@:6}"

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outfile=${nb_output_repo}/abscal_inspect/abscal_inspect_${jd}.ipynb

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}
export ABSCAL_MODEL_GLOB=${model_files_glob}
export LST_BLACKLIST_STRING=${lst_blacklists}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to notebook \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/stage_2_abscal.ipynb

python ${src_dir}/build_notebook_readme.py ${nb_output_repo}/abscal_inspect

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin master
    git add ${nb_outfile}
    git commit -m "H1C IDR3 abscal notebook for JD ${jd}"
    git push origin master
fi
