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
dly_filt_horizon=${4}
dly_filt_standoff=${5}
dly_filt_min_dly=${6}
dly_filt_eigenval_cutoff=${7}
FM_low_freq=${8}
FM_high_freq=${9}
save_diff_red_avg=${10}
save_abs_cal_red_avg=${11}
save_dly_filt_red_avg=${12}
calibrate_cross_pols=${13}

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export SUM_SUFFIX="sum.uvh5"
export DIFF_SUFFIX="diff.uvh5"
export ABS_CAL_SUFFIX="sum.omni.calfits"
export SMOOTH_CAL_SUFFIX="sum.smooth.calfits"
export APOSTERIORI_YAML_SUFFIX="_aposteriori_flags.yaml"
export FILTER_CACHE="filter_cache"
export SUM_ABS_CAL_RED_AVG_DLY_FILT_SUFFIX="sum.abs_calibrated.red_avg.dly_filt.uvh5"
export DIFF_ABS_CAL_RED_AVG_DLY_FILT_SUFFIX="diff.abs_calibrated.red_avg.dly_filt.uvh5"
export SUM_SMOOTH_CAL_RED_AVG_DLY_FILT_SUFFIX="sum.smooth_calibrated.red_avg.dly_filt.uvh5"
export DIFF_SMOOTH_CAL_RED_AVG_DLY_FILT_SUFFIX="diff.smooth_calibrated.red_avg.dly_filt.uvh5"
export SUM_ABS_CAL_RED_AVG_SUFFIX="sum.abs_calibrated.red_avg.uvh5"
export DIFF_ABS_CAL_RED_AVG_SUFFIX="diff.abs_calibrated.red_avg.uvh5"
export SUM_SMOOTH_CAL_RED_AVG_SUFFIX="sum.smooth_calibrated.red_avg.uvh5"
export DIFF_SMOOTH_CAL_RED_AVG_SUFFIX="diff.smooth_calibrated.red_avg.uvh5"
export AVG_ABS_ALL_SUFFIX="sum.smooth_calibrated.avg_abs_all.uvh5"
export AVG_ABS_AUTO_SUFFIX="sum.smooth_calibrated.avg_abs_auto.uvh5"
export AVG_ABS_CROSS_SUFFIX="sum.smooth_calibrated.avg_abs_cross.uvh5"
export DLY_FILT_HORIZON=${dly_filt_horizon}
export DLY_FILT_STANDOFF=${dly_filt_standoff}
export DLY_FILT_MIN_DLY=${dly_filt_min_dly}
export DLY_FILT_EIGENVAL_CUTOFF=${dly_filt_eigenval_cutoff}
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export SAVE_DIFF_RED_AVG=${save_diff_red_avg}
export SAVE_ABS_CAL_RED_AVG=${save_abs_cal_red_avg}
export SAVE_DLY_FILT_RED_AVG=${save_dly_filt_red_avg}
export SAVE_CROSS_POLS=${calibrate_cross_pols}

nb_outfile=${SUM_FILE%.uvh5}.postprocessing_notebook.html

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/file_postprocessing.ipynb
echo Finished running file postprocessing notebook at $(date)

# Check a representative set of files to see whether they were correctly produced
for suffix in ${AVG_ABS_ALL_SUFFIX} ${AVG_ABS_AUTO_SUFFIX} ${AVG_ABS_CROSS_SUFFIX}; do 
    outfile=${SUM_FILE%sum.uvh5}${suffix}
    if [ -f "$outfile" ]; then
        echo Resulting $outfile found.
    else
        echo $outfile not produced.
        exit 1
    fi
done
if [ "${save_dly_filt_red_avg}" == "True" ]; then
    outfile=${SUM_FILE%sum.uvh5}${SUM_SMOOTH_CAL_RED_AVG_DLY_FILT_SUFFIX}
    if [ -f "$outfile" ]; then
        echo Resulting $outfile found.
    else
        echo $outfile not produced.
        exit 1
    fi
    if [ "${save_abs_cal_red_avg}" == "True" ]; then
        outfile=${SUM_FILE%sum.uvh5}${SUM_ABS_CAL_RED_AVG_DLY_FILT_SUFFIX}
        if [ -f "$outfile" ]; then
            echo Resulting $outfile found.
        else
            echo $outfile not produced.
            exit 1
        fi
    fi
    if [ "${save_diff_red_avg}" == "True" ]; then
        outfile=${SUM_FILE%sum.uvh5}${DIFF_SMOOTH_CAL_RED_AVG_DLY_FILT_SUFFIX}
        if [ -f "$outfile" ]; then
            echo Resulting $outfile found.
        else
            echo $outfile not produced.
            exit 1
        fi
    fi
fi
outfile=${SUM_FILE%sum.uvh5}${SUM_SMOOTH_CAL_RED_AVG_SUFFIX}
if [ -f "$outfile" ]; then
    echo Resulting $outfile found.
else
    echo $outfile not produced.
    exit 1
fi

# Get JD from filename
jd=$(get_int_jd ${fn})
is_middle_file=`python -c "import glob; files=sorted(glob.glob('zen.*${jd}*.sum.uvh5')); print('${fn}' == files[len(files) // 2])"`
if [ "${is_middle_file}" == "True" ]; then
    # Copy file to notebook directory and rebuild html
    cp ${nb_outfile} ${nb_output_repo}/file_postprocessing/file_postprocessing_${jd}.html
    python ${src_dir}/build_notebook_index.py ${nb_output_repo}
fi
