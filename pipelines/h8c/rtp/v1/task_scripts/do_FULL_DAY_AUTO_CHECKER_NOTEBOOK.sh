#! /bin/bash
set -e

# This script generates a "scouting" notebook that examines all autos for a night

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - upload_to_librarian: global boolean trigger
# 6 - librarian_full_day_auto_checker: boolean trigger for this step
# 7+ - various settings

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
upload_to_librarian=${5}
librarian_full_day_auto_checker=${6}

export MAX_ZEROS_PER_EO_SPEC_GOOD=${7}
export MAX_ZEROS_PER_EO_SPEC_SUSPECT=${8}
export AUTO_POWER_GOOD_LOW=${9}
export AUTO_POWER_GOOD_HIGH=${10}
export AUTO_POWER_SUSPECT_LOW=${11}
export AUTO_POWER_SUSPECT_HIGH=${12}
export AUTO_SLOPE_GOOD_LOW=${13}
export AUTO_SLOPE_GOOD_HIGH=${14}
export AUTO_SLOPE_SUSPECT_LOW=${15}
export AUTO_SLOPE_SUSPECT_HIGH=${16}
export AUTO_RFI_GOOD=${17}
export AUTO_RFI_SUSPECT=${18}
export AUTO_SHAPE_GOOD=${19}
export AUTO_SHAPE_SUSPECT=${20}
export BAD_XENGINE_ZCUT=${21}
export RFI_DPSS_HALFWIDTH=${22}
export RFI_NSIG=${23}
export FREQ_FILTER_SCALE=${24}
export TIME_FILTER_SCALE=${25}
export EIGENVAL_CUTOFF=${26}
export FM_LOW_FREQ=${27}
export FM_HIGH_FREQ=${28}
export MAX_SOLAR_ALT=${29}
export SMOOTHED_ABS_Z_THRESH=${30}
export WHOLE_DAY_FLAG_THRESH=${31}

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

# If desired, push results to github
if [ "${git_push}" == "True" ]; then
    if [ $(stat -c %s "${nb_outfile}") -lt 100000000 ]; then
        cd ${nb_output_repo}
        git pull origin main || echo 'Unable to git pull origin main. Perhaps the internet is down?'
        git add ${nb_outfile}
        python ${src_dir}/build_notebook_readme.py ${nb_outdir}
        git add ${nb_outdir}/README.md
        lasturl=`python -c "readme = open('${nb_outdir}/README.md', 'r'); print(readme.readlines()[-1].split('(')[-1].split(')')[0])"`
        git commit -m "Full-day auto-checker notebook for JD ${jd}" -m ${lasturl}
        git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
    else
        echo ${nb_outfile} is too large to upload to github.
    fi
fi
