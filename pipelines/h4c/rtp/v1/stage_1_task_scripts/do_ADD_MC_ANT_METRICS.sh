#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent wtih the config.
# 1 - (raw) filename
# 2 - good_extension: Extension to be appended to the file name.
# 3 - maybe_extension: Extension to be appended to the file name.
# 4 - all_extension: Extension to be appended to the file name.
fn=${1}
good_extension=${2}
maybe_extension=${3}
all_extension=${4}

# We only want to upload ant metrics on sum files
# check if the string does not contain the word diff
if ! stringContain diff "${fn}"; then
  # get ant_metrics filename
  metrics_f="${fn%.*}"${good_extension}
  echo add_qm_metrics.py --type=ant ${metrics_f}
  add_qm_metrics.py --type=ant ${metrics_f}

  # get ant_metrics filename
  metrics_f="${fn%.*}"${maybe_extension}
  echo add_qm_metrics.py --type=ant ${metrics_f}
  add_qm_metrics.py --type=ant ${metrics_f}

  # get ant_metrics filename
  metrics_f="${fn%.*}"${all_extension}
  echo add_qm_metrics.py --type=ant ${metrics_f}
  add_qm_metrics.py --type=ant ${metrics_f}
fi
