#! /bin/bash
set -e

# This script deletes all raw data and RTP data products for a single day by deleting the whole folder containing the input file.
# It should only be run once the full RTP is done and everything we want to keep has been uploaded to the Librarian.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
fn=${1}

# get name of current directory
full_path="$(realpath "${fn}")"
folder_path_containing_fn="$(dirname "${full_path}")"

# get JD and folder name and make sure they match before deleting it
folder_name="$(basename "${folder_path_containing_fn}")"
jd=$(get_int_jd ${fn})
if [ "${folder_name}" == "${jd}" ]; then
    echo "Now deleting ${folder_path_containing_fn}"
    echo "rm -rf ${folder_path_containing_fn}"
    rm -rf ${folder_path_containing_fn}
fi
