#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# the args are
# 1 - input file name.
# 2 - label
# 3 - path to beam file
# 4 - group string identifier

fn="${1}"
include_diffs="${2}"
label="${3}"
beamfile_stem="${4}"


jd=$(get_jd $fn)
int_jd=${jd:0:7}

sumdiff=("sum" "diff")
pol_label_list=("" "_pstokes")
for sd in ${sumdiff[@]}
do
  for pol_label in ${pol_label_list[@]}
  do
    beamfile=${beamfile_stem}${pol_label}.fits
    psc=zen.${jd}.${sd}.${label}.xtalk_filtered${pol_label}.tavg.pspec.h5
    echo ${psc}
    if [ -e "${psc}" ]
    then
      dfile=zen.${jd}.sum.${label}.xtalk_filtered${pol_label}.tavg.uvh5
      if [ -e "${dfile}" ]
      then
        echo auto_noise_run.py ${psc} ${dfile} ${beamfile} --err_type 'P_N' 'P_SN'
        auto_noise_run.py ${psc} ${dfile} ${beamfile} --err_type 'P_N' 'P_SN'
      fi
    fi
  done
done
