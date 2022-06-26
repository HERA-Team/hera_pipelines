#! /bin/bash
set -e

# This script generates a notebook for inspecting power-spectra output by the RTP.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - identifier label.
# 6 -spws list of integers for spws to inspect separated by commas with no spaces: e.g. "0,1,2"
# 7 - list of lst ranges with the lower/upper of each range separated by tildes and each field by commas. NO SPACES@
#     example: 1~3,4.2,6.2 will trigger inspecting fields with LST range 1-3 hours and 4.2-6.2 hours.
# 8 - inspect every N redundant baseline groups when breaking redundant groups out into invidual baselines.
# 9 - number of baseline pairs to skip when processing blpair averaged plots.
# 10 - labels for each lst field separated by commans with no spaces, ex: "1,2".
# 11 -

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
label=${5}



# Get JD from filename
jd=$(get_jd $fn)
int_jd=${jd:0:7}


nb_outfile=${nb_output_repo}/gain_jump_calibration_inspect/gain_jump_inspect_${label}_${jd}.ipynb
# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${int_jd}
export LABEL=${label}


# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to notebook \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/inspect_gain_jump_calibration.ipynb
# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin master
    git add ${nb_outfile}
    git commit -m "H4C RTP Gain Jump Calibration Notebook for JD ${jd} ${label}"
    git push origin master
fi
