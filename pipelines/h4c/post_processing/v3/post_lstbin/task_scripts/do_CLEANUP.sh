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
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  rm -rf zen.${grpstr}.LST.${lst}.${sd}.${label}*waterfall*h5
  rm -rf zen.${grpstr}.LST.${lst}.${sd}.${label}*chunked*h5

done
