#! /bin/bash
set -e

# This script generates a notebook for inspecting foreground and x-talk filtered time-averaged data.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - identifier label.
# 6 - number of redundant groups to show in plots
# 7 - maximum number of baselines to show per redundant group.
# 8 - number of redundant groups to skip over when plotting the number of redundant groups specified in $6.

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
label=${5}
nreds=${6}
max_bls_per_redgrp=${7}
nskip=${8}


# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outfile=${nb_output_repo}/filter_output_inspect/filter_output_inspect_${label}_${jd}.ipynb

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}
export LABEL=${label}
export NREDS=${nreds}
export MAX_BLS_PER_REDGRP=${max_bls_per_redgrp}
export NSKIP=${nskip}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to notebook \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/filter_output_inspect.ipynb

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin master
    git add ${nb_outfile}
    git commit -m "H4C RTP Filtering notebook for JD ${jd} ${label}"
    git push origin master
fi
