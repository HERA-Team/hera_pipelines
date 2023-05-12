#! /bin/bash
set -e

# This script generates a notebook that post-processes a single file, producing various calibrated and averaged data products.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5+ - various settings
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
dly_filt_horizon=${5}
dly_filt_standoff=${6}
dly_filt_min_dly=${7}
dly_filt_eigenval_cutoff=${8}
FM_low_freq=${9}
FM_high_freq=${10}

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export SUM_SUFFIX="sum.uvh5"
export DIFF_SUFFIX="diff.uvh5"
export ABS_CAL_SUFFIX="sum.omni.calfits"
export SMOOTH_CAL_SUFFIX="sum.smooth.calfits"
export APOSTERIORI_YAML_SUFFIX="_aposteriori_flags.yaml"
export FILTER_CACHE="filter_cache"
export SUM_ABSCAL_RED_AVG_SUFFIX="sum.abs_calibrated.red_avg.uvh5"
export DIFF_ABSCAL_RED_AVG_SUFFIX="diff.abs_calibrated.red_avg.uvh5"
export SUM_SMOOTH_CAL_RED_AVG_SUFFIX="sum.smooth_calibrated.red_avg.uvh5"
export DIFF_SMOOTH_CAL_RED_AVG_SUFFIX="diff.smooth_calibrated.red_avg.uvh5"
export SUM_SMOOTH_CAL_RED_AVG_DLY_FILT_SUFFIX="sum.smooth_calibrated.red_avg.dly_filt.uvh5"
export DIFF_SMOOTH_CAL_RED_AVG_DLY_FILT_SUFFIX="diff.smooth_calibrated.red_avg.dly_filt.uvh5"
export AVG_ABS_ALL_SUFFIX="sum.smooth_calibrated.avg_abs_all.uvh5"
export AVG_ABS_AUTO_SUFFIX="sum.smooth_calibrated.avg_abs_auto.uvh5"
export AVG_ABS_CROSS_SUFFIX="sum.smooth_calibrated.avg_abs_cross.uvh5"
export DLY_FILT_HORIZON=${dly_filt_horizon}
export DLY_FILT_STANDOFF=${dly_filt_standoff}
export DLY_FILT_MIN_DLY=${dly_filt_min_dly}
export DLY_FILT_EIGENVAL_CUTOFF=${dly_filt_eigenval_cutoff}
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}

nb_outfile=${SUM_FILE%.uvh5}.postprocessing_notebook.html

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/file_postprocessing.ipynb
echo Finished running file postprocessing notebook at $(date)

# Check to see that output files were correctly produced
for suffix in ${SUM_ABSCAL_RED_AVG_SUFFIX} ${SUM_SMOOTH_CAL_RED_AVG_SUFFIX} ${SUM_SMOOTH_CAL_RED_AVG_DLY_FILT_SUFFIX} ${AVG_ABS_ALL_SUFFIX} ${AVG_ABS_AUTO_SUFFIX} ${AVG_ABS_CROSS_SUFFIX}; do
    outfile=${SUM_FILE%sum.uvh5}${suffix}
    if [ -f "$outfile" ]; then
        echo Resulting $outfile found.
    else
        echo $f not produced.
        exit 1
    fi
done
for suffix in ${DIFF_ABSCAL_RED_AVG_SUFFIX} ${DIFF_SMOOTH_CAL_RED_AVG_SUFFIX} ${DIFF_SMOOTH_CAL_RED_AVG_DLY_FILT_SUFFIX}; do
    DIFF_FILE=${SUM_FILE%sum.uvh5}diff.uvh5
    outfile=${DIFF_FILE%diff.uvh5}${suffix}
    if [ -f "$outfile" ]; then
        echo Resulting $outfile found.
    else
        echo $f not produced.
        exit 1
    fi
done

# Get JD from filename
jd=$(get_int_jd ${fn})
is_middle_file=`python -c "import glob; files=sorted(glob.glob('zen.*${jd}*.sum.uvh5')); print('${fn}' == files[len(files) // 2])"`
if [ "${is_middle_file}" == "True" ]; then
    # Copy file to github repo
    github_nb_outdir=${nb_output_repo}/file_postprocessing
    github_nb_outfile=${github_nb_outdir}/file_postprocessing_${jd}.html
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
        git commit -m "File post-processing notebook for JD ${jd}" -m ${lasturl}
        git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
    fi
fi
