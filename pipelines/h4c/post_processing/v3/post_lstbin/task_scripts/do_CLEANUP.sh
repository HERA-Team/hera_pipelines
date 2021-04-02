#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"
grpstr="${3}"

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
# get rid of all the waterfall files associated with this run.
rm -rf zen.${grpstr}.LST.${lst}.${label}*waterfall*h5
