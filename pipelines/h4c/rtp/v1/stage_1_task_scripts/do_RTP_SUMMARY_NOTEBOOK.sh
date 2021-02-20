#! /bin/bash
set -e

# This script generates an HTML version of a notebook for inspecting autocorrelations for outliers

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - ant_metrics_ext: extension for ant_metrics files to use
# 3 - redcal_ext: extension for redcal files to use
# 4 - nb_template_dir: where to look for the notebook template
# 5 - nb_output_repo: repository for saving evaluated notebooks
# 6 - git_push: boolean whether to push the results created in the nb_output_repo
fn=${1}
ant_metrics_ext=${2}
redcal_ext=${3}
nb_template_dir=${4}
nb_output_repo=${5}
git_push=${6}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/_rtp_summary_
if [ ! -d ${nb_outdir} ]; then
  mkdir -p ${nb_outdir}
fi
nb_outfile=${nb_outdir}rtp_summary_${jd}.html

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}
export ANT_METRICS_EXT=${ant_metrics_ext}
export REDCAL_EXT=${redcal_ext}
export NB_OUTDIR=${nb_outdir}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/rtp_summary.ipynb

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin master
    git add ${nb_outfile}
    git add rtp_summary_table_${jd}.csv
    python ${src_dir}/build_notebook_readme.py ${nb_outdir}
    git add ${nb_outdir}/README.md
    git commit -m "RTP summary notebook for JD ${jd}"
    git push origin master
fi
