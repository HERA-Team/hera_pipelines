#! /bin/bash
set -e

# This script generates a notebook that reduces a file to a delay-filtered, redundantly average metric for finding RFI

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
FM_low_freq=${4}
FM_high_freq=${5}
min_samp_frac=${6}
filter_delay=${7}
eigenval_cutoff=${8}

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export SUM_SUFFIX="sum.uvh5"
export SMOOTH_CAL_SUFFIX="sum.smooth.calfits"
export ZSCORE_SUFFIX="sum.red_avg_zscore.h5"
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export MIN_SAMP_FRAC=${min_samp_frac}
export FILTER_DELAY=${filter_delay}
export EIGENVAL_CUTOFF=${eigenval_cutoff}

nb_outfile=${SUM_FILE%.uvh5}.delay_filtered_average_zscore_notebook.html

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/delay_filtered_average_zscore.ipynb
echo Finished running file delay-filtered average z-score notebook at $(date)

# check that output metric file was produced as expected
outfile=${SUM_FILE%sum.uvh5}${ZSCORE_SUFFIX}
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
    # Copy file to github repo
    github_nb_outdir=${nb_output_repo}/delay_filtered_average_zscore
    github_nb_outfile=${github_nb_outdir}/delay_filtered_average_zscore_${jd}.html
    cp ${nb_outfile} ${github_nb_outfile}
fi
