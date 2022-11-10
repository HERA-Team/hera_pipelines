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
auto_rfi_good_low=${19}
auto_rfi_good_high=${20}
auto_rfi_suspect_low=${21}
auto_rfi_suspect_high=${22}
auto_shape_good=${23}
auto_shape_suspect=${24}
oc_cspa_good=${25}
oc_cspa_suspect=${26}
oc_max_dims=${27}
oc_min_dim_size=${28}
oc_skip_outriggers=${29}
oc_maxiter=${30}
oc_max_rerun=${31}
rfi_dpss_halfwidth=${32}
rfi_nsig=${33}

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
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
export AUTO_RFI_GOOD_LOW=${auto_rfi_good_low}
export AUTO_RFI_GOOD_HIGH=${auto_rfi_good_high}
export AUTO_RFI_SUSPECT_LOW=${auto_rfi_suspect_low}
export AUTO_RFI_SUSPECT_HIGH=${auto_rfi_suspect_high}
export AUTO_SHAPE_GOOD=${auto_shape_good}
export AUTO_SHAPE_SUSPECT=${auto_shape_suspect}
export OC_CSPA_GOOD=${oc_cspa_good}
export OC_CSPA_SUSPECT=${oc_cspa_suspect}
export OC_MAX_DIMS=${oc_max_dims}
export OC_MIN_DIM_SIZE=${oc_min_dim_size}
export OC_SKIP_OUTRIGGERS=${oc_skip_outriggers}
export OC_MAXITER=${oc_maxiter}
export OC_MAX_RERUN=${oc_max_rerun}
export RFI_DPSS_HALFWIDTH=${rfi_dpss_halfwidth}
export RFI_NSIG=${rfi_nsig}

nb_outfile=${SUM_FILE%.uvh5}.calibration_notebook.html

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/file_calibration.ipynb
echo Finished running file calibration notebook at $(date)

# Check to see that output files were correctly produced
am_file=${SUM_FILE%.uvh5}.ant_metrics.hdf5
antclass_file=${SUM_FILE%.uvh5}.ant_class.csv
omnical_file=${SUM_FILE%.uvh5}.omni.calfits
omnivis_file=${SUM_FILE%.uvh5}.omni_vis.uvh5
for f in ${am_file} ${antclass_file} ${omnical_file} ${omnivis_file}; do
    if [ -f "$f" ]; then
        echo Resulting $f found.
    else
        echo $f not produced.
        exit 1
    fi
done

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    # Get JD from filename
    jd=$(get_int_jd ${fn})
    is_middle_file=`python -c "import glob; files=sorted(glob.glob('zen.*${jd}*.sum.uvh5')); print('${fn}' == files[len(files) // 2])"`
    if [ "${is_middle_file}" == "True" ]
    then
        # Copy file to github repo
        github_nb_outdir=${nb_output_repo}/file_calibration
        github_nb_outfile=${github_nb_outdir}/file_calibration_${jd}.html
        cp ${nb_outfile} ${github_nb_outfile}

        # Push to github
        cd ${nb_output_repo}
        git pull origin main || echo 'Unable to git pull origin main. Perhaps the internet is down?'
        git add ${github_nb_outfile}
        python ${src_dir}/build_notebook_readme.py ${github_nb_outdir}
        git add ${github_nb_outdir}/README.md
        lasturl=`python -c "readme = open('${github_nb_outdir}/README.md', 'r'); print(readme.readlines()[-1].split('(')[-1].split(')')[0])"`
        git commit -m "File calibration notebook for JD ${jd}" -m ${lasturl}
        git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
    fi
fi
