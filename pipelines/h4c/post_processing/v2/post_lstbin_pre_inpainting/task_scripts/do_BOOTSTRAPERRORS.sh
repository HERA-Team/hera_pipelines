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
label="${2}"
grpstr="${3}"
nsamples="${4}"
seed="${5}"



lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`


sumdiff=("sum" "diff")

for sd in ${sumdiff[@]}
do
  psc=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.tavg.pspec.h5
  echo bootstrap_run.py ${psc} --Nsamples ${nsamples} --seed ${seed} --normal_std --robust_std
  bootstrap_run.py ${psc} --Nsamples ${nsamples} --seed ${seed} --normal_std --robust_std
done
