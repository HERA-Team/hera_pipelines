#! /bin/bash
set -e

# This script generates a notebook for inspecting the results of reflection calibration, delay filtering, and cross-talk filtering

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
horizon=${5}
standoff=${6}
min_dly=${7}
max_frate_const_term=${8}
max_frate_linear_term=${9}
min_frate_half_width=${10}
max_frate_half_width=${11}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outfile=${nb_output_repo}/systematics_mitigation_inspect/systematics_mitigation_inspect_${jd}.ipynb

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}
export HORIZON=${horizon}
export STANDOFF=${standoff}
export MIN_DLY=${min_dly}
export MAX_FRATE_CONST_TERM=${max_frate_const_term}
export MAX_FRATE_LINEAR_TERM=${max_frate_linear_term}
export MIN_FRATE_HALF_WIDTH=${min_frate_half_width}
export MAX_FRATE_HALF_WIDTH=${max_frate_half_width}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
                  --to notebook \
                  --ExecutePreprocessor.allow_errors=True \
                  --ExecutePreprocessor.timeout=-1 \
                  --execute ${nb_template_dir}/h1c_systematics_mitigation_inspect.ipynb

python ${src_dir}/build_notebook_readme.py ${nb_output_repo}/systematics_mitigation_inspect

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin master
    git add ${nb_outfile}
    git commit -m "H1C IDR3 systematics mitigation notebook for JD ${jd}"
    git push origin master
fi
