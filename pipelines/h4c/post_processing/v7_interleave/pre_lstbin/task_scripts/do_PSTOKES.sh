#! /bin/bash

#-----------------------------------------------------------------------------
# This script computes psuedo-stokes (pstokes) visibilities as a power-spectrum
# pre-processing step.
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
# 4) pstokes: tab separated list of pstokes labels to calculate. "pI pQ" for example.
#    upstream throws away xx, yy by default so pI and pQ are the only ones that
#    will typically work.
#
# ASSUMED INPUTS:
# 1) stalk filtered, delay inpainted, time-averaged sum/diff files with
#    XX and YY polarizations with naming format
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.tavg.uvh5
# OUTPUTS:
# 1) sum/diff xtalk filtered, delay inpainted, time-averaged sum/diff files
#    with pStokes polarizations included. Naming convention is
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered_pstokes.tavg.uvh5
#
#-----------------------------------------------------------------------------



fn="${1}"
include_diffs="${2}"
label="${3}"
pstokes="${@:4}"

echo "hello"
echo ${label}
echo ${pstokes}

jd=$(get_jd $fn)
int_jd=${jd:0:7}
exts=("foreground_filled")


if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi

for sd in ${sumdiff[@]}
do
  for ext in ${exts[@]}
  do
    # compute pstokes of xtalk filtered files.
    input=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.tavg.uvh5
    output=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered_pstokes.tavg.uvh5
    if [ -e "${input}" ]
    then
      echo generate_pstokes_run.py ${input} ${pstokes} --clobber --outputdata ${output}
      generate_pstokes_run.py ${input} --pstokes ${pstokes} --clobber --outputdata ${output}
    else
      echo "${input} does not exist!"
    fi
  done
done
