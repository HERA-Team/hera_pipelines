#! /bin/bash
set -e

# This script generates an HTML version of a notebook which performs full-day antenna flag harmonization.
# It also zips up resultant UVFlag files and adds them to the librarian

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4+ - various settings
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
oc_skip_outriggers=${25}
smoothing_scale_nfiles=${26}
max_flag_gap_nfiles=${27}
auto_power_max_flag_frac=${28}
auto_shape_max_flag_frac=${29}
auto_slope_max_flag_frac=${30}
auto_rfi_max_flag_frac=${31}
chisq_max_flag_frac=${32}
xengine_max_flag_frac=${33}
overall_max_flag_frac=${34}
path_to_a_priori_flags=${35}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/full_day_antenna_flagging
nb_outfile=${nb_outdir}/full_day_antenna_flagging_${jd}.html

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export SUM_SUFFIX="sum.uvh5"
export CAL_SUFFIX="sum.omni.calfits"
export ANT_CLASS_SUFFIX="sum.ant_class.csv"
export OUT_FLAG_SUFFIX="sum.antenna_flags.h5"
export APRIORI_YAML_PATH=${path_to_a_priori_flags}/${jd}_apriori_flags.yaml
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
export OC_SKIP_OUTRIGGERS=${oc_skip_outriggers}

export SMOOTHING_SCALE_NFILES=${smoothing_scale_nfiles}
export POWER_MAX_FLAG_FRAC=${max_flag_gap_nfiles}
export AUTO_POWER_MAX_FLAG_FRAC=${auto_power_max_flag_frac}
export AUTO_SHAPE_MAX_FLAG_FRAC=${auto_shape_max_flag_frac}
export AUTO_SLOPE_MAX_FLAG_FRAC=${auto_slope_max_flag_frac}
export AUTO_RFI_MAX_FLAG_FRAC=${auto_rfi_max_flag_frac}
export CHISQ_MAX_FLAG_FRAC=${chisq_max_flag_frac}
export XENGINE_MAX_FLAG_FRAC=${xengine_max_flag_frac}
export OVERALL_MAX_FLAG_FRAC=${overall_max_flag_frac}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/full_day_antenna_flagging.ipynb
echo Finished full-day antenna flagging notebook at $(date)

# Check to see that at least one output file was correctly produced
first_outfile=${SUM_FILE%.sum.uvh5}.sum.antenna_flags.h5
if [ -f "$first_outfile" ]; then
    echo Resulting $first_outfile found.
else
    echo $first_outfile not produced.
    exit 1
fi

python ${src_dir}/build_notebook_index.py ${nb_outdir}
