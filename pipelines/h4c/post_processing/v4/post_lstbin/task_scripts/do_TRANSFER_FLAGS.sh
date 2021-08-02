#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# This script averages data in time.
# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - template file name (template for time chunk to reconstitute).
# 2 - data extension
# 2 - output label for identifying file.
# 3 - number of seconds to average in time.

fn="${1}"
include_diffs="${2}"
label="${3}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
fi




if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi
exts=("foreground_res" "foreground_model")

for sd in ${sumdiff[@]}
do
  for ext in ${exts[@]}
  do
    input_file=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.uvh5
    output_file=zen.${jd}.${sd}.${label}.${ext}.filled_flags.xtalk_filtered.uvh5
    if [ -e "${input_file}" ]
    then
        # transfer flags from res file to model file.
        echo transfer_flags.py zen.${jd}.${sd}.${label}.foreground_filled.xtalk_filtered.uvh5 ${input_file} ${output_file} --clobber
        transfer_flags.py zen.${jd}.${sd}.${label}.foreground_filled.xtalk_filtered.uvh5 ${input_file} ${output_file} --clobber
    else
      echo "${input_file} does not exist!"
    fi
  done
done
