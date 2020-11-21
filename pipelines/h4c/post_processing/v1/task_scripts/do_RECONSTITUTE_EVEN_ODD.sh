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

if [ -e "${templatefile}" ]
then
  parities=("even" "odd")
  for parity in ${parities[@]}
  do
    # reconstitute xtalk filtered files with no foregrounds
    outfilename=zen.${jd}.${parity}.${label}.xtalk_filtered_res.${data_ext}
    fragment_list=`echo zen.${int_jd}.*.${parity}.${label}.xtalk_filtered_waterfall_res.${data_ext}`
    tfile=zen.${jd}.${parity}.${label}.xtalk_filtered_waterfall_res.${data_ext}
    if [ -e "${tfile}" ]
    then
      echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
          --fragmentlist ${fragment_list} --clobber

      reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
          --fragmentlist ${fragment_list} --clobber
    else
      echo "noforeground files were not produced."
    fi

    outfilename=zen.${jd}.${parity}.${label}.xtalk_filtered_withforegrounds.${data_ext}
    fragment_list=`echo zen.${int_jd}.*.${parity}.${label}.xtalk_filtered_waterfall_withforegrounds.${data_ext}`


    echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
        --fragmentlist ${fragment_list} --clobber

    reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
        --fragmentlist ${fragment_list} --clobber

    # time averaged data
    outfilename=zen.${jd}.${parity}.${label}.xtalk_filtered_withforegrounds.tavg.${data_ext}
    fragment_list=`echo zen.${int_jd}.*.${parity}.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.${data_ext}`

    echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
        --fragmentlist ${fragment_list} --clobber --time_bounds

    reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
        --fragmentlist ${fragment_list} --clobber --time_bounds


    # reconstitute xtalk filtered files with foregrounds but low fringe-rates filled in.
    outfilename=zen.${jd}.even.${label}.withforegrounds.${data_ext}
    fragment_list=`echo zen.${int_jd}.*.even.${label}.waterfall_withforegrounds.${data_ext}`


    echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
        --fragmentlist ${fragment_list} --clobber

    reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
        --fragmentlist ${fragment_list} --clobber


    # time averaged data
    outfilename=zen.${jd}.even.${label}.withforegrounds.tavg.${data_ext}
    fragment_list=`echo zen.${int_jd}.*.even.${label}.waterfall_withforegrounds.tavg.${data_ext}`


    echo reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
        --fragmentlist ${fragment_list} --clobber --time_bounds

    reconstitute_filtered_files_run.py ${templatefile} --outfilename ${outfilename}\
        --fragmentlist ${fragment_list} --clobber --time_bounds

  done

else
  echo "${templatefile} does not exist!"
fi
