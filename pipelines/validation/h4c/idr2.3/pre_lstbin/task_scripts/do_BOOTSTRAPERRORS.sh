#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# the args are
# 1 - input file name.
# 2 - label
# 3 - group string identifier
# 4 - number of samples in bootstrap
# 5 - bootstrap seed.

fn="${1}"
include_diffs="${2}"
label="${3}"
nsamples="${4}"
seed="${5}"




jd=$(get_jd $fn)
int_jd=${jd:0:7}


if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi


pol_label_list=("", "_pstokes")

for sd in ${sumdiff[@]}
do
  for pol_label in ${pol_label_list[@]}
    do
    psc=zen.${jd}.${sd}.${label}.xtalk_filtered${pol_label}.tavg.pspec.h5
    if [ -e "${psc}" ]
    then
      echo bootstrap_run.py ${psc} --Nsamples ${nsamples} --seed ${seed} --robust_std True --overwrite
      bootstrap_run.py ${psc} --Nsamples ${nsamples} --seed ${seed} --robust_std True --overwrite
    else
      echo "${psc} does not exist!"
    fi
  done
done
