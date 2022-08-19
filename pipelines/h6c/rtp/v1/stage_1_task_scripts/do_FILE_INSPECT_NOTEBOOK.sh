#! /bin/bash
set -e

# This script generates a notebook examining a single file 

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5+ - various bounds
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
am_corr_bad=${5}
am_corr_suspect=${6}
am_xpol_bad=${7}
am_xpol_suspect=${8}
auto_power_good_low=${9}
auto_power_good_high=${10}
auto_power_suspect_low=${11}
auto_power_suspect_high=${12}
auto_slope_good_low=${13}
auto_slope_good_high=${14}
auto_slope_suspect_low=${15}
auto_slope_suspect_high=${16}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/file_inspect
nb_outfile=${nb_outdir}/file_inspect_${jd}.ipynb

# Export variables used by the notebook
export SUM_FILE=`realpath ${fn}`
export AM_CORR_BAD=${am_corr_bad}
export AM_CORR_SUSPECT=${am_corr_suspect}
export AM_XPOL_BAD=${am_xpol_bad}
export AM_XPOL_SUSPECT=${am_xpol_suspect}
export AUTO_POWER_GOOD_LOW=${auto_power_good_low}
export AUTO_POWER_GOOD_HIGH=${auto_power_good_high}
export AUTO_POWER_SUSPECT_LOW=${auto_power_suspect_low}
export AUTO_POWER_SUSPECT_HIGH=${auto_power_suspect_high}
export AUTO_SLOPE_GOOD_LOW=${auto_slope_good_low}
export AUTO_SLOPE_GOOD_HIGH=${auto_slope_good_high}
export AUTO_SLOPE_SUSPECT_LOW=${auto_slope_suspect_low}
export AUTO_SLOPE_SUSPECT_HIGH=${auto_slope_suspect_high}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to notebook \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/file_inspect.ipynb
echo Finished running file inspect notebook at $(date)

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin main || echo 'Unable to git pull origin main. Perhaps the internet is down?'
    git add ${nb_outfile}
    python ${src_dir}/build_notebook_readme.py ${nb_outdir}
    git add ${nb_outdir}/README.md
    lasturl=`python -c "readme = open('${nb_outdir}/README.md', 'r'); print(readme.readlines()[-1].split('(')[-1].split(')')[0])"`
    git commit -m "RTP file inspection for JD ${jd}" -m ${lasturl}
    git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
fi
