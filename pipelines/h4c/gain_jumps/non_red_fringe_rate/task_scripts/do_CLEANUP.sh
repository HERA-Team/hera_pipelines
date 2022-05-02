#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

# all intermediary data files.

fn_cln=zen.*.${label}.*.uvh5
cmd="rm -rf ${fn_cln}"

echo ${cmd}
${cmd}
