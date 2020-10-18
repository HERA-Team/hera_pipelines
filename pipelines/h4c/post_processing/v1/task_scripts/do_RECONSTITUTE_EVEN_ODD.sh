#! /bin/bash
set -e

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
data_ext="${2}"
label="${3}"

templatefile=${fn%.uvh5}.${label}.chunked.${data_ext}
jd=$(get_jd $templatefile)
int_jd=${jd:0:7}

if [ -e "${fn_in}" ]
then
  # reconstitute xtalk filtered files with no foregrounds
  outfilename_even=zen.${jd}.even.${label}.xtalk_filtered_noforegrounds_res.${data_ext}
  fragment_list_even=`echo zen.${int_jd}.*.even.${label}.xtalk_filtered_waterfall_noforegrounds_res.${data_ext}`
  outfilename_odd=${outfilename_even/even/odd}
  fragment_list_odd=`echo zen.${int_jd}.*.odd.${label}.xtalk_filtered_waterfall_noforegrounds_res.${data_ext}`


  echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_even}\
      --fragmentlist ${fragment_list_even} --clobber

  reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_even}\
      --fragmentlist ${fragment_list_even} --clobber


  echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_odd}\
      --fragmentlist ${fragment_list_odd} --clobber

  reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_odd}\
          --fragmentlist ${fragment_list_odd} --clobber


  # reconstitute xtalk filtered files with foregrounds but low fringe-rates filtered
  outfilename_even=zen.${jd}.even.${label}.xtalk_filtered_withforegrounds_res.${data_ext}
  fragment_list_even=`echo zen.${int_jd}.*.even.${label}.xtalk_filtered_waterfall_withforegrounds_res.${data_ext}`
  outfilename_odd=${outfilename_even/even/odd}
  fragment_list_odd=`echo zen.${int_jd}.*.odd.${label}.xtalk_filtered_waterfall_withforegrounds_res.${data_ext}`


  echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_even}\
      --fragmentlist ${fragment_list_even} --clobber

  reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_even}\
      --fragmentlist ${fragment_list_even} --clobber


  echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_odd}\
      --fragmentlist ${fragment_list_odd} --clobber

  reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_odd}\
          --fragmentlist ${fragment_list_odd} --clobber


  # reconstitute xtalk filtered files with foregrounds but low fringe-rates filtered
  outfilename_even=zen.${jd}.even.${label}.xtalk_filtered_withforegrounds_filled.${data_ext}
  fragment_list_even=`echo zen.${int_jd}.*.even.${label}.xtalk_filtered_waterfall_withforegrounds_filled.${data_ext}`
  outfilename_odd=${outfilename_even/even/odd}
  fragment_list_odd=`echo zen.${int_jd}.*.odd.${label}.xtalk_filtered_waterfall_withforegrounds_filled.${data_ext}`


  echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_even}\
      --fragmentlist ${fragment_list_even} --clobber

  reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_even}\
      --fragmentlist ${fragment_list_even} --clobber


  echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_odd}\
      --fragmentlist ${fragment_list_odd} --clobber

  reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename_odd}\
          --fragmentlist ${fragment_list_odd} --clobber
else
  echo "${templatefile} does not exist!"
fi
