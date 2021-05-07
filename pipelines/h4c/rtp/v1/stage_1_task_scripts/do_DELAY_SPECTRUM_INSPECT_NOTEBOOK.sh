#! /bin/bash
set -e

# This script generates a notebook for inspecting delay spectrum of autocorrelations

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
nb_outdir=${nb_output_repo}/delay_spectrum_inspect
if [ ! -d ${nb_outdir} ]; then
  mkdir -p ${nb_outdir}
fi
nb_outfile=${nb_outdir}/delay_spectrum_inspect_${jd}.html
csv_outfile=${nb_outdir}/ds_noise_ratio_${jd}.csv

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}
export NB_OUTDIR=${nb_outdir}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/delay_spectrum_inspect.ipynb

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin main
    git add ${nb_outfile}
    git add ${csv_outfile}
    python ${src_dir}/build_notebook_readme.py ${nb_outdir}
    git add ${nb_outdir}/README.md
    lasturl=`python -c "readme = open('${nb_outdir}/README.md', 'r'); print(readme.readlines()[-1].split('(')[-1].split(')')[0])"`
    git commit -m "RTP delay spectrum inspection notebook commit for JD ${jd}" -m ${lasturl}
    git push origin main
fi
