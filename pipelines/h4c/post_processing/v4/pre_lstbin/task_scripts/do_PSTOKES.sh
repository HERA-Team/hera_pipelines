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
label="${2}"
grpstr="${3}"
pstokes="${@:3}"



jd=$(get_jd $fn)
int_jd=${jd:0:7}


sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # compute pstokes of xtalk filtered files.
  input=zen.${jd}.${sd}.${label}.xtalk_filtered.tavg.uvh5
  output=zen.${jd}.${sd}.${label}.xtalk_filtered_pstokes.tavg.uvh5
  if [ -e "${input}" ]
  then
    echo generate_pstokes_run.py ${input} ${pstokes} --clobber --outputdata ${output}
    generate_pstokes_run.py ${input} --pstokes ${pstokes} --clobber --outputdata ${output}
  else
    echo "${input} does not exist!"
  fi
done
