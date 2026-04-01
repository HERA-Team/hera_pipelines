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
# 4+ - various bounds and settings
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
am_corr_bad=${4}
am_corr_suspect=${5}
am_xpol_bad=${6}
am_xpol_suspect=${7}
suspect_solar_alt=${8}
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
auto_shape_good=${21}
auto_shape_suspect=${22}
oc_cspa_good=${23}
oc_cspa_suspect=${24}
oc_max_dims=${25}
oc_min_dim_size=${26}
oc_skip_outriggers=${27}
oc_min_bl_len=${28}
oc_max_bl_len=${29}
oc_maxiter=${30}
oc_max_rerun=${31}
oc_rerun_maxiter=${32}
oc_max_chisq_flagging_dynamic_range=${33}
oc_use_prior_sol=${34}
oc_prior_sol_flag_thresh=${35}
rfi_dpss_halfwidth=${36}
rfi_nsig=${37}
abscal_min_bl_len=${38}
abscal_max_bl_len=${39}
save_omni_vis=${40}
calibrate_cross_pols=${41}

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
export OC_MAX_CHISQ_FLAGGING_DYNAMIC_RANGE=${oc_max_chisq_flagging_dynamic_range}
export OC_USE_PRIOR_SOL=${oc_use_prior_sol}
export OC_PRIOR_SOL_FLAG_THRESH=${oc_prior_sol_flag_thresh}
export RFI_DPSS_HALFWIDTH=${rfi_dpss_halfwidth}
export RFI_NSIG=${rfi_nsig}
export ABSCAL_MIN_BL_LEN=${abscal_min_bl_len}
export ABSCAL_MAX_BL_LEN=${abscal_max_bl_len}
export SAVE_OMNIVIS_FILE=${save_omni_vis}
export CALIBRATE_CROSS_POLS=${calibrate_cross_pols}

# if SUM_FILE with .sum. replaced with .diff. does not exist, export USE_DIFF=False
if [ ! -e "${SUM_FILE/.sum./.diff.}" ]; then
    export USE_DIFF=False
fi

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
    python ${src_dir}/build_notebook_index.py ${github_nb_outdir}
fi
