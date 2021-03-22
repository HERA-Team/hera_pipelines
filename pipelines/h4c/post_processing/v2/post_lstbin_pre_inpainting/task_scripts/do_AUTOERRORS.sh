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
label="${2}"
beamfile="${3}"
grpstr="${4}"


lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`


sumdiff=("sum" "diff")

for sd in ${sumdiff[@]}
do
  psc=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.tavg.pspec.h5
  auto=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.tavg.uvh5
  echo auto_noise_run.py ${psc} ${auto} ${beamfile} --err_type 'P_N' 'P_SN'
  auto_noise_run.py ${psc} ${auto} ${beamfile} --err_type 'P_N' 'P_SN'
done
