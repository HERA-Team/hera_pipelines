#! /bin/bash
set -e

# This script generates a "scouting" notebook that examines all autos for a night

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - upload_to_librarian: global boolean trigger
# 5 - librarian_full_day_auto_checker: boolean trigger for this step
# 6+ - various settings

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
upload_to_librarian=${4}
librarian_full_day_auto_checker=${5}

export MAX_ZEROS_PER_EO_SPEC_GOOD=${6}
export MAX_ZEROS_PER_EO_SPEC_SUSPECT=${7}
export AUTO_POWER_GOOD_LOW=${8}
export AUTO_POWER_GOOD_HIGH=${9}
export AUTO_POWER_SUSPECT_LOW=${10}
export AUTO_POWER_SUSPECT_HIGH=${11}
export AUTO_SLOPE_GOOD_LOW=${12}
export AUTO_SLOPE_GOOD_HIGH=${13}
export AUTO_SLOPE_SUSPECT_LOW=${14}
export AUTO_SLOPE_SUSPECT_HIGH=${15}
export AUTO_RFI_GOOD=${16}
export AUTO_RFI_SUSPECT=${17}
export AUTO_SHAPE_GOOD=${18}
export AUTO_SHAPE_SUSPECT=${19}
export BAD_XENGINE_ZCUT=${20}
export RFI_DPSS_HALFWIDTH=${21}
export RFI_NSIG=${22}
export FREQ_FILTER_SCALE=${23}
export TIME_FILTER_SCALE=${24}
export EIGENVAL_CUTOFF=${25}
export FM_LOW_FREQ=${26}
export FM_HIGH_FREQ=${27}
export MAX_SOLAR_ALT=${28}
export SMOOTHED_ABS_Z_THRESH=${29}
export WHOLE_DAY_FLAG_THRESH=${30}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/full_day_auto_checker
nb_outfile=${nb_outdir}/full_day_auto_checker_${jd}.html
sum_file="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"

# Export the other arguments directly
export SUM_AUTOS_SUFFIX="sum.autos.uvh5"
export DIFF_AUTOS_SUFFIX="diff.autos.uvh5"
export OUT_YAML_SUFFIX="_apriori_flags.yaml"
export AUTO_FILE=${sum_file%sum.uvh5}${SUM_AUTOS_SUFFIX}
out_yaml_file=${jd}${OUT_YAML_SUFFIX}

# Execute jupyter notebook
cmd="jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--ExecutePreprocessor.kernel_name=${conda_env} \
--execute ${nb_template_dir}/full_day_auto_checker.ipynb"
echo $cmd
eval $cmd
echo Finished running full-day auto-checker notebook at $(date)

if [ -f "$out_yaml_file" ]; then
    echo Resulting $f found.
    cp ${out_yaml_file} ${nb_outdir}
else
    echo $f not produced.
    exit 1
fi

# Rebuild index.html for this notebook's folder
python ${src_dir}/build_notebook_index.py ${nb_outdir}

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_full_day_auto_checker}" == "True" ]; then
        yaml_for_librarian=`echo ${fn%.uvh5}${OUT_YAML_SUFFIX}`
        yaml_for_librarian=`basename ${yaml_for_librarian}`
        echo librarian upload local-rtp ${out_yaml_file} ${jd}/${yaml_for_librarian}
        librarian upload local-rtp ${out_yaml_file} ${jd}/${yaml_for_librarian}
        echo Finished uploading ${yaml_for_librarian} to the Librarian at ${jd}/${librarian_file} at $(date)
    fi
fi
