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
  if [ -e "${auto}" ]
  then
    xcorr=zen.${jd}.${sd}.${label}.xtalk_filtered.tavg.uvh5
    echo generate_pstokes_run.py ${xcorr} ${pstokes} --clobber
    generate_pstokes_run.py ${xcorr} --pstokes ${pstokes} --clobber
  else
    echo "${xcorr} does not exist!"
  fi
done
