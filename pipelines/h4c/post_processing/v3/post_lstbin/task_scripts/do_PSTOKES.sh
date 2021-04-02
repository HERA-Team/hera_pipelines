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
label="${3}"
grpstr="${2}"
pstokes="${@:4}"


lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`

sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # compute pstokes of autocorrelation
  auto=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.foreground_filled.tavg.uvh5
  if [ -e "${auto}" ]
  then
    echo generate_pstokes_run.py ${auto} ${pstokes} --clobber
    generate_pstokes_run.py ${auto} --pstokes ${pstokes} --clobber
  fi

  # compute pstokes of xtalk filtered files.
  if [ -e "${auto}" ]
  then
    xcorr=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.tavg.uvh5
    echo generate_pstokes_run.py ${xcorr} ${pstokes} --clobber
    generate_pstokes_run.py ${xcorr} --pstokes ${pstokes} --clobber
  fi
done
