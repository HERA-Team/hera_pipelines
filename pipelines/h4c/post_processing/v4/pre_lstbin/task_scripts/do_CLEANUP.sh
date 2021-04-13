#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
# get rid of all the waterfall files associated with this run.
rm -rf zen.${jd}.*.${label}*waterfall*h5
