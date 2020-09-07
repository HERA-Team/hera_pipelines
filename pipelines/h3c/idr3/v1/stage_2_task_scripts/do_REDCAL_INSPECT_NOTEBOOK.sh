#! /bin/bash
set -e

# This script generates a notebook for inspecting the results of redundant baseline calibration for stage 2 analysis

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
ant_metrics_extension=${5}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outfile=${nb_output_repo}/stage_2_redcal/stage_2_redcal_${jd}.ipynb

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to notebook \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/stage_2_redcal.ipynb

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin master
    git add ${nb_outfile}
    git commit -m "H3C IDR3 stage 2 redcal notebook for JD ${jd}"
    git push origin master
fi
