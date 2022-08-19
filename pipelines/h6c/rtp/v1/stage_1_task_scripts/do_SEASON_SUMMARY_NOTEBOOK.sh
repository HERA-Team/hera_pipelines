#! /bin/bash
set -e

# This script generates an HTML version of a notebook summarizing the csv output of all rtp_summary notebooks this season.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - nb_template_dir: where to look for the notebook template
# 2 - nb_output_repo: repository for saving evaluated notebooks
# 3 - git_push: boolean whether to push the results created in the nb_output_repo
nb_template_dir=${1}
nb_output_repo=${2}
git_push=${3}

# Export variables used by the notebook
export CSV_FOLDER=${nb_output_repo}/_rtp_summary_

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_output_repo}/Season_Summary.html \
--to html \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/Season_Summary.ipynb
echo Finished finished running season summary notebook at $(date)

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin main || echo 'Unable to git pull origin main. Perhaps the internet is down?'
    git add ${nb_output_repo}/Season_Summary.html
    git commit -m "Update season summary notebook."
    git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
fi
