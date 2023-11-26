#! /bin/bash
set -e

# This script generates an HTML version of a notebook summarizing the output of auto_metrics, ant_metrics, and redcal chisq

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - good_statuses: string list of comma-separated (no spaces) antenna statuses considered "good"

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
good_statuses=${5}

redcal_ext=".known_good.omni.calfits"

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/_rtp_summary_
nb_outfile=${nb_outdir}/rtp_summary_${jd}.html

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}
export ANT_METRICS_EXT=.ant_metrics.hdf5
export REDCAL_EXT=${redcal_ext}
export NB_OUTDIR=${nb_outdir}
export GOOD_STATUSES=${good_statuses}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/rtp_summary.ipynb
echo Finished finished running rtp_summary notebook at $(date)

# If desired, push results to github
if [ "${git_push}" == "True" ]; then
    if [ $(stat -c %s "${nb_outfile}") -lt 100000000 ]; then
        cd ${nb_output_repo}
        git pull origin main || echo 'Unable to git pull origin main. Perhaps the internet is down?'
        git add ${nb_outfile}
        git add ${nb_outdir}/rtp_summary_table_${jd}.csv
        git add ${nb_outdir}/array_health_table_${jd}.csv
        python ${src_dir}/build_notebook_readme.py ${nb_outdir}
        git add ${nb_outdir}/README.md
        lasturl=`python -c "readme = open('${nb_outdir}/README.md', 'r'); print(readme.readlines()[-1].split('(')[-1].split(')')[0])"`
        git commit -m "RTP summary notebook for JD ${jd}" -m ${lasturl}
        git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
    else
        echo ${nb_outfile} is too large to upload to github.
    fi
fi
