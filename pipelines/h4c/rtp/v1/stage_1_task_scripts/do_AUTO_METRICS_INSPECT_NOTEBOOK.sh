#! /bin/bash
set -e

# This script generates an HTML version of a notebook for inspecting autocorrelations for outliers

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

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/auto_metrics_inspect
if [ ! -d ${nb_outdir} ]; then
  mkdir -p ${nb_outdir}
fi
nb_outfile=${nb_outdir}/auto_metrics_inspect_${jd}.html

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/auto_metrics_inspect.ipynb

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin master
    git add ${nb_outfile}
    git commit -m "RTP auto_metrics inspect notebook for JD ${jd}"
    git push origin master
fi