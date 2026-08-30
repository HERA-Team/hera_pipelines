#! /bin/bash

# this cleanup script will only leaave
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
fi

# get rid of all the waterfall files associated with this run.
rm -rf zen.${jd}.*.${label}*waterfall*h5
# also get rid of the chunked files.
rm -rf zen.${jd}.*.${label}*chunked*h5
# remove tavg files.
rm -rf zen.${jd}.*.${label}*tavg.*
