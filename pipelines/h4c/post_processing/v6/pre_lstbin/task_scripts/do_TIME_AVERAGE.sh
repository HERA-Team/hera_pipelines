#! /bin/bash

#-----------------------------------------------------------------------------
# This script performs coherent LST-averages of full night waterfall files
#-----------------------------------------------------------------------------


set -e

# sometimes /tmp gets filled up on NRAO nodes hence this line.
# haven't need to use it recently.
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/
#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

#-----------------------------------------------------------------------------
# ARGUMENTS
# 1) fn: Input filename (string) assumed to contain JD.
# 2) include_diffs: Whether or not to perform analysis on diff files as well as sum files.
#    valid options are "true" or "false".
# 3) label: identifying string label for analysis outputs to set it apart from other
#    runs with different parameters.
# 4) t_avg: (float) number of seconds to perform coherent averaging over.
#
# ASSUMED INPUTS
# 1) sum/diff xtalk subtracted waterfall files
#    zen.<jd>.<sum/diff>.<label>.foreground_fille.d.xtalk_filtered.waterfall.uvh5
#    these files contain a small number of baselines and all time integrations for the night
#    To convert to files with a small number of time integrations and all baselines we must use
# 2) (optional) sum/diff xtalk time-inpainted files
#    zen.<jd>.<sum/diff>.<label>.foreground_fille.d.time_inpainted.waterfall.uvh5
#    these files contain a small number of baselines and all time integrations for the night
#    To convert to files with a small number of time integrations and all baselines we must use

# OUTPUTS
# 1) coherently averaged sum/diff xtalk subtracted waterfall files.
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.waterfall.tavg.uvh5
# 2) (optional) coherently averaged sum/diff time-inpainted waterfall files.
#   zen.${jd}.${sd}.${label}.foreground_filled.time_inpainted.waterfall.tavg.uvh5
#-----------------------------------------------------------------------------

fn="${1}"
include_diffs="${2}"
label="${3}"
t_avg="${4}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}


if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi
exts=("foreground_filled")

for sd in ${sumdiff[@]}
do
# time average time-inpainted files and xtalk-filtered files.
  input_file=zen.${jd}.${sd}.${label}.foreground_filled.time_inpainted.waterfall.uvh5
  output_file=zen.${jd}.${sd}.${label}.foreground_filled.time_inpainted.waterfall.tavg.uvh5
  if [ -e "${input_file}" ]
  then
    echo time_average.py ${input_file} ${output_file} --t_avg ${t_avg} --wgt_by_favg_nsample --clobber
    time_average.py ${input_file} ${output_file} --t_avg ${t_avg} --wgt_by_favg_nsample --clobber
  else
    echo "${input_file} does not exist!"
  fi
  for ext in ${exts[@]}
  do
    input_file=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.uvh5
    file_list=`echo zen.${int_jd}.*.${sd}.${label}.${ext}.xtalk_filtered.uvh5`
    output_file=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.waterfall.tavg.uvh5
    if [ -e "${input_file}" ]
    then
      echo time_average.py ${file_list} ${output_file} --cornerturnfile ${input_file} --t_avg ${t_avg} --dont_wgt_by_nsample --clobber
      time_average.py ${file_list} ${output_file}  --cornerturnfile ${input_file} --t_avg ${t_avg} --dont_wgt_by_nsample --clobber
    else
      echo "${input_file} does not exist!"
    fi
  done
done
