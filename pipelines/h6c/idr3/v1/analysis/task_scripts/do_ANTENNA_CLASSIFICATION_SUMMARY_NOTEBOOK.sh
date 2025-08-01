#! /bin/bash
set -e

# This script generates an HTML version of a notebook providing a daily summary of the antenna classifications
# produced by the file_calibration notebooks.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - oc_skip_outriggers: whether to skip outriggers (and thus flag them) when doing redcal

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
oc_skip_outriggers=${4}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/antenna_classification_summary
nb_outfile=${nb_outdir}/antenna_classification_summary_${jd}.html
middle_file=`python -c "import glob; files=sorted(glob.glob('zen.*${jd}*.sum.uvh5')); print(files[len(files) // 2])"`

# Export variables used by the notebook
export ANT_CLASS_FOLDER="$(cd "$(dirname "${middle_file}")" && pwd)"
export SUM_FILE="$(cd "$(dirname "${middle_file}")" && pwd)/$(basename "${middle_file}")"
export OC_SKIP_OUTRIGGERS=${oc_skip_outriggers}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/antenna_classification_summary.ipynb
echo Finished finished antenna classification summary notebook at $(date)

python ${src_dir}/build_notebook_index.py ${nb_outdir}
