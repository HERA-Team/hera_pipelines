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
# 5+ - various bounds and settings
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
am_corr_bad=${5}
am_corr_suspect=${6}
am_xpol_bad=${7}
am_xpol_suspect=${8}
zeros_per_spec_good=${9}
zeros_per_spec_suspect=${10}
auto_power_good_low=${11}
auto_power_good_high=${12}
auto_power_suspect_low=${13}
auto_power_suspect_high=${14}
auto_slope_good_low=${15}
auto_slope_good_high=${16}
auto_slope_suspect_low=${17}
auto_slope_suspect_high=${18}
auto_rfi_good=${19}
auto_rfi_suspect=${20}
oc_cspa_good=${21}
oc_cspa_suspect=${22}
oc_max_dims=${23}
oc_min_dim_size=${24}
oc_skip_outriggers=${25}
oc_maxiter=${26}
oc_max_rerun=${27}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/file_inspect
nb_outfile=${nb_outdir}/file_inspect_${jd}.html

# Export variables used by the notebook
export SUM_FILE=`realpath ${fn}`
export AM_CORR_BAD=${am_corr_bad}
export AM_CORR_SUSPECT=${am_corr_suspect}
export AM_XPOL_BAD=${am_xpol_bad}
export AM_XPOL_SUSPECT=${am_xpol_suspect}
export MAX_ZEROS_PER_EO_SPEC_GOOD=${zeros_per_spec_good}
export MAX_ZEROS_PER_EO_SPEC_SUSPECT=${zeros_per_spec_suspect}
export AUTO_POWER_GOOD_LOW=${auto_power_good_low}
export AUTO_POWER_GOOD_HIGH=${auto_power_good_high}
export AUTO_POWER_SUSPECT_LOW=${auto_power_suspect_low}
export AUTO_POWER_SUSPECT_HIGH=${auto_power_suspect_high}
export AUTO_SLOPE_GOOD_LOW=${auto_slope_good_low}
export AUTO_SLOPE_GOOD_HIGH=${auto_slope_good_high}
export AUTO_SLOPE_SUSPECT_LOW=${auto_slope_suspect_low}
export AUTO_SLOPE_SUSPECT_HIGH=${auto_slope_suspect_high}
export OC_CSPA_GOOD=${oc_cspa_good}
export OC_CSPA_SUSPECT=${oc_cspa_suspect}
export OC_MAX_DIMS=${oc_max_dims}
export OC_MIN_DIM_SIZE=${oc_min_dim_size}
export OC_SKIP_OUTRIGGERS=${oc_skip_outriggers}
export OC_MAXITER=${oc_maxiter}
export OC_MAX_RERUN=${oc_max_rerun}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
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
    git commit -m "File Inspect notebook for JD ${jd}" -m ${lasturl}
    git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
fi
