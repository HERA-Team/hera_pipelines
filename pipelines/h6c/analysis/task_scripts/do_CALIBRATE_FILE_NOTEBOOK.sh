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
suspect_solar_alt=${9}
zeros_per_spec_good=${10}
zeros_per_spec_suspect=${11}
auto_power_good_low=${12}
auto_power_good_high=${13}
auto_power_suspect_low=${14}
auto_power_suspect_high=${15}
auto_slope_good_low=${16}
auto_slope_good_high=${17}
auto_slope_suspect_low=${18}
auto_slope_suspect_high=${19}
auto_rfi_good=${20}
auto_rfi_suspect=${21}
auto_shape_good=${22}
auto_shape_suspect=${23}
oc_cspa_good=${24}
oc_cspa_suspect=${25}
oc_max_dims=${26}
oc_min_dim_size=${27}
oc_skip_outriggers=${28}
oc_min_bl_len=${29}
oc_max_bl_len=${30}
oc_maxiter=${31}
oc_max_rerun=${32}
oc_rerun_maxiter=${33}
oc_use_prior_sol=${34}
oc_prior_sol_flag_thresh=${35}
rfi_dpss_halfwidth=${36}
rfi_nsig=${37}
abscal_min_bl_len=${38}
abscal_max_bl_len=${39}
save_omni_vis=${40}

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export AM_CORR_BAD=${am_corr_bad}
export AM_CORR_SUSPECT=${am_corr_suspect}
export AM_XPOL_BAD=${am_xpol_bad}
export AM_XPOL_SUSPECT=${am_xpol_suspect}
export SUSPECT_SOLAR_ALTITUDE=${suspect_solar_alt}
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
export AUTO_RFI_GOOD=${auto_rfi_good}
export AUTO_RFI_SUSPECT=${auto_rfi_suspect}
export AUTO_SHAPE_GOOD=${auto_shape_good}
export AUTO_SHAPE_SUSPECT=${auto_shape_suspect}
export OC_CSPA_GOOD=${oc_cspa_good}
export OC_CSPA_SUSPECT=${oc_cspa_suspect}
export OC_MAX_DIMS=${oc_max_dims}
export OC_MIN_DIM_SIZE=${oc_min_dim_size}
export OC_SKIP_OUTRIGGERS=${oc_skip_outriggers}
export OC_MIN_BL_LEN=${oc_min_bl_len}
export OC_MAX_BL_LEN=${oc_max_bl_len}
export OC_MAXITER=${oc_maxiter}
export OC_MAX_RERUN=${oc_max_rerun}
export OC_RERUN_MAXITER=${oc_rerun_maxiter}
export OC_USE_PRIOR_SOL=${oc_use_prior_sol}
export OC_PRIOR_SOL_FLAG_THRESH=${oc_prior_sol_flag_thresh}
export RFI_DPSS_HALFWIDTH=${rfi_dpss_halfwidth}
export RFI_NSIG=${rfi_nsig}
export ABSCAL_MIN_BL_LEN=${abscal_min_bl_len}
export ABSCAL_MAX_BL_LEN=${abscal_max_bl_len}
export SAVE_OMNIVIS_FILE=${save_omni_vis}

nb_outfile=${SUM_FILE%.uvh5}.calibration_notebook.html

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/file_calibration.ipynb
echo Finished running file calibration notebook at $(date)

# Check to see that output files were correctly produced
am_file=${SUM_FILE%.uvh5}.ant_metrics.hdf5
antclass_file=${SUM_FILE%.uvh5}.ant_class.csv
omnical_file=${SUM_FILE%.uvh5}.omni.calfits
for f in ${am_file} ${antclass_file} ${omnical_file}; do
    if [ -f "$f" ]; then
        echo Resulting $f found.
    else
        echo $f not produced.
        exit 1
    fi
done

omnivis_file=${SUM_FILE%.uvh5}.omni_vis.uvh5
if [ "${save_omni_vis}" == "True" ]; then
    if [ -f "${omnivis_file}" ]; then
        echo Resulting $f found.
    else
        echo $f not produced.
        exit 1
    fi
fi

# Get JD from filename
jd=$(get_int_jd ${fn})
is_middle_file=`python -c "import glob; files=sorted(glob.glob('zen.*${jd}*.sum.uvh5')); print('${fn}' == files[len(files) // 2])"`
if [ "${is_middle_file}" == "True" ]; then
    # Copy file to github repo
    github_nb_outdir=${nb_output_repo}/file_calibration
    github_nb_outfile=${github_nb_outdir}/file_calibration_${jd}.html
    cp ${nb_outfile} ${github_nb_outfile}
    
    # If desired, push results to github
    if [ "${git_push}" == "True" ]; then
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
