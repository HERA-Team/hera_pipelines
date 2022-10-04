#! /bin/bash
set -e

# This script generates an HTML version of a notebook summarizing the output of auto_metrics, ant_metrics, and redcal chisq

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - good_statuses: string list of comma-separated (no spaces) antenna statuses considered "good"

src_dir="$(dirname "$0")"
echo ${src_dir}/do_RTP_SUMMARY_NOTEBOOK_1.sh ${1} ${2} ${3} ${4} ${5}
${src_dir}/do_RTP_SUMMARY_NOTEBOOK_1.sh ${1} ${2} ${3} ${4} ${5}
