#! /bin/bash
set -e

# This script throws away baselines from antennas that are flagged in apriori yaml file.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
yaml_dir="${2}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

yaml_file=${yaml_dir}/${jd_int}.yaml

sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  input=zen.${jd}.${sd}.uvh5
  output=zen.${jd}.${sd}.uvh5
  output_autos=zen.${jd}.${sd}.autos.uvh5
  echo throw_away_flagged_antennas.py ${input} ${output} --yaml_file ${yaml_file} --clobber
  throw_away_flagged_antennas.py ${input} ${output} --yaml_file ${yaml_file} --clobber
  # extract autos
  echo extract_autos.py ${output} ${output_autos} --clobber
done
