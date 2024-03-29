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
t_avg="${4}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
fi



if [ "${include_diffs}" == "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi


exts=( "frf" "foreground_filled.xtalk_filtered.chunked" )
for sd in ${sumdiff[@]}
do
  for ext in ${exts[@]}
  do
    if [ "${ext}" = "frf" ]
    then
      # frf files are already in waterfalls.
      filelist=`echo zen.${jd}.${sd}.${label}.${ext}.*.waterfall.uvh5`
      output_file=zen.${jd}.${sd}.${label}.${ext}.waterfall.tavg.uvh5
      # reconstitute spw_ranges in this step as well.
      # check if the list actually gave you a list.
      if echo x"$filelist" | grep '*' > /dev/null; then
        echo "No waterfall files exist with ${jd}. This is probably because there are more times then baseline groups."
      else
        echo time_average.py ${filelist} ${output_file} --t_avg ${t_avg} --dont_wgt_by_nsample --clobber
        time_average.py ${filelist} ${output_file}  --t_avg ${t_avg} --dont_wgt_by_nsample --clobber
      fi
    else
      # need to do cornerturn for fgfilled files.
      input_file=zen.${jd}.${sd}.${label}.${ext}.uvh5
      output_file=zen.${jd}.${sd}.${label}.${ext}.waterfall.tavg.uvh5
      filelist=`echo zen.*.${sd}.${label}.${ext}.uvh5`
      if [ -e "${input_file}" ]
      then
        echo time_average.py ${filelist} ${output_file} --cornerturnfile ${input_file}  --t_avg ${t_avg} --dont_wgt_by_nsample --clobber
        time_average.py ${filelist} ${output_file} --cornerturnfile ${input_file}  --t_avg ${t_avg} --dont_wgt_by_nsample --clobber
      else
        echo "${input_file} does not exist!"
      fi
    fi
  done
done
