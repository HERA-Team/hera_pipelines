#! /bin/bash
set -e

# This script generates a notebook for inspecting the results of data-only RFI identification

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
nb_outdir=${nb_output_repo}/rfi_inspect
if [ ! -L ${nb_outdir} ]; then
  if [ ! -d ${nb_outdir} ]; then
    mkdir -p ${nb_outdir}
  fi
else
  if [! -d `readlink -f ${nb_outdir}`]; then
    mkdir -p ${nb_outdir}
  fi
fi
nb_outfile=${nb_outdir}/rfi_inspect_${jd}.ipynb

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to notebook \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/rfi_inspect.ipynb
echo Finished running RFI inspect notebook at $(date)

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin main || echo 'Unable to git pull origin main. Perhaps the internet is down?'
    git add ${nb_outfile}
    python ${src_dir}/build_notebook_readme.py ${nb_outdir}
    git add ${nb_outdir}/README.md
    lasturl=`python -c "readme = open('${nb_outdir}/README.md', 'r'); print(readme.readlines()[-1].split('(')[-1].split(')')[0])"`
    git commit -m "RTP RFI inspection notebook commit for JD ${jd}" -m ${lasturl}
    git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
fi
