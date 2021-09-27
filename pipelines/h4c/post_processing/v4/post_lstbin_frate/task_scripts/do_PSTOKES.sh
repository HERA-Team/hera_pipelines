#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# the args are
# 1 - input file name.
# 2 - label
# 3 - group string identifier
# 4 - pstokes to calculate

fn="${1}"
include_diffs="${2}"
label="${3}"
pstokes="${@:4}"



jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
fi


if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi

for sd in ${sumdiff[@]}
do
  exts=( "foreground_filled.chunked" "frf" "foreground_filled.xtalk_filtered.chunked" )
  for ext in ${exts[@]}
  do
    # compute pstokes of fr filtered files.
    input=zen.${jd}.${sd}.${label}.${ext}.tavg.uvh5
    output=zen.${jd}.${sd}.${label}.${ext}_pstokes.tavg.uvh5
    if [ -e "${input}" ]
    then
      echo generate_pstokes_run.py ${input} ${pstokes} --clobber --outputdata ${output}
      generate_pstokes_run.py ${input} --pstokes ${pstokes} --clobber --outputdata ${output}
    else
      echo "${input} does not exist!"
    fi
  done
done
