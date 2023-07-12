#! /bin/bash
set -e

# This script generates one HTML notebook for each atennna, summarizing relevant info from auto_metrics and rtp_summary notebooks this season.

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

# loop over antennas in the data file
antennas=`python -c "from pyuvdata import UVData; import numpy as np; uv = UVData(); uv.read('${fn}', read_data=False); print(' '.join([str(ant).zfill(3) for ant in (set(uv.ant_1_array) | set(uv.ant_2_array))]))"`
for antenna in $antennas; do
    # Export variables used by the notebook
    export ANTENNA=$antenna
    export CSV_FOLDER=${nb_output_repo}/_rtp_summary_
    export AUTO_METRICS_FOLDER=${nb_output_repo}/auto_metrics_inspect

    # Execute jupyter notebook and save as HTML
    jupyter nbconvert --output=${nb_output_repo}/antenna_report/antenna_${antenna}_report.html \
    --to html \
    --ExecutePreprocessor.allow_errors=True \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/antenna_report.ipynb
    echo Finished finished running antenna ${antenna} report summary notebook at $(date)

    # If desired, push results to github
    if [ "${git_push}" == "True" ]
    then
        cd ${nb_output_repo}
        git pull origin main || echo 'Unable to git pull origin main. Perhaps the internet is down?'
        git add ${nb_output_repo}/antenna_report/antenna_*_report.html
        python ${src_dir}/build_notebook_readme.py ${nb_output_repo}/antenna_report
        git add ${nb_output_repo}/antenna_report/README.md
        git commit -m "Update report for antenna ${antenna}."
        git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
    fi
done
