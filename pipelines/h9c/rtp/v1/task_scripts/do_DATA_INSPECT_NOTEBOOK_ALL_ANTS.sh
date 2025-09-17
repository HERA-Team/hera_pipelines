#! /bin/bash
set -e

# This script generates a notebook inspecting data for all antennas

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - apriori_statuses: string list of comma-separated (no spaces) antenna statuses to include here
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
apriori_statuses=${4}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/data_inspect_all_ants
nb_outfile=${nb_outdir}/data_inspect_all_ants_${jd}.html

# Export variables used by the notebook
export DATA_PATH=`pwd`
export JULIANDATE=${jd}
export APRIORI_STATUSES=${apriori_statuses}

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.allow_errors=True \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/data_inspect.ipynb
echo Finished running data_inspect notebook for all ants at $(date)

# Rebuild index.html for this notebook's folder
python ${src_dir}/build_notebook_index.py ${nb_outdir}
