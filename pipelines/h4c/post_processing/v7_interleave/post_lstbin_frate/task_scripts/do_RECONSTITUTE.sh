#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# This script reconstitutes as time chunk from many baselines.
# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - template file name (template for time chunk to reconstitute).
# 2 - data extension
# 2 - output label for identifying file.

fn="${1}"
include_diffs="${2}"
label="${3}"
ninterleave="${4}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  int_jd="LST"
  jd="LST.${jd}"
fi



if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi

for sd in ${sumdiff[@]}
do
  exts=("frf" "foreground_filled.xtalk_filtered.chunked" )
  for ext in ${exts[@]}
  do
    time_chunk_template=zen.${jd}.${sd}.${label}.foreground_filled.xtalk_filtered.chunked.uvh5
    if [ -e "${time_chunk_template}" ]
    then
	# iterate through interleaves
	for ((ilabel=0; ilabel < ${ninterleave}; ilabel++))
	do
	    echo ${ilabel}
            # reconstitute frf files
            outfilename=zen.${jd}.${sd}.${label}.${ext}.tavg.interleave_${ilabel}.uvh5
            baseline_chunk_files=`echo zen.${int_jd}.*.${sd}.${label}.${ext}.waterfall.tavg.interleave_${ilabel}.uvh5`
            if echo x"$baseline_chunk_files" | grep '*' > /dev/null; then
		echo "No waterfall files exist with ${jd}. This is probably because there are more times then baseline groups."
            else
		cmd = "time_chunk_from_baseline_chunks_run.py ${time_chunk_template} --baseline_chunk_files ${baseline_chunk_files} --clobber --time_bounds --outfilename ${outfilename}"
		echo ${cmd}
		${cmd}
            fi
	done
    else
      echo "${time_chunk_template} does not exist!"
    fi
  done
done
