#! /bin/bash
set -e

# This function sets all the flags to False and all the nsamples to 1 and overwrites the file

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - binary switch as to whether to do this step
fn="${1}"
fix_datafile="${2}"

if [ "${fix_datafile}" == "True" ]; then
    echo python ${src_dir}/fix_datafile.py ${fn} ${fn}
    python ${src_dir}/fix_datafile.py ${fn} ${fn}
fi
