#! /bin/bash
set -e

# This script generates a notebook inspecting data from a priori known good antennas

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - apriori_statuses: string list of comma-separated (no spaces) antenna statuses to include here
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
apriori_statuses=${5}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/data_inspect_known_good
if [ ! -d ${nb_outdir} ]; then
  mkdir -p ${nb_outdir}
fi
nb_outfile=${nb_outdir}/data_inspect_known_good_${jd}.ipynb

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}
export APRIORI_STATUSES=${apriori_statuses}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to notebook \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/data_inspect.ipynb

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin main
    git add ${nb_outfile}
    python ${src_dir}/build_notebook_readme.py ${nb_outdir}
    git add ${nb_outdir}/README.md
    lasturl=`python -c "readme = open('${nb_outdir}/README.md', 'r'); print(readme.readlines()[-1].split('(')[-1].split(')')[0])"`
    git commit -m "RTP data inspection of known good antennas for JD ${jd}" -m ${lasturl}
    git push origin main
fi
