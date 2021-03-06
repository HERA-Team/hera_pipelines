#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"
data_ext="${3}"
cal_ext="${4}"
chunk_size="${5}"
spw0="${6}"
spw1="${7}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

# chunk data files
input_data=zen.${jd}.sum.${data_ext}
output_data=zen.${jd}.sum.${label}.chunked.${data_ext}
input_data_diff=${input_data/sum/diff}
output_data_diff=${output_data/sum/diff}
datafiles=`echo zen.${int_jd}.*.sum.${data_ext}`
datafiles_diff=`echo zen.${int_jd}.*.diff.${data_ext}`

input_auto=zen.${jd}.sum.autos.uvh5
output_auto=zen.${jd}.sum.${label}.autos.chunked.uvh5
input_auto_diff=${input_auto/sum/diff}
output_auto_diff=${output_auto/sum/diff}
autofiles=`echo zen.${int_jd}.*.sum.autos.uvh5`
autofiles_diff=`echo zen.${int_jd}.*.diff.autos.uvh5`

input_cal=zen.${jd}.sum.${cal_ext}
output_cal=zen.${jd}.sum.${label}.chunked.${cal_ext}
calfiles=`echo zen.${int_jd}.*.sum.${cal_ext}`


# chunk data sum files.
echo chunk_data_files.py ${datafiles} ${input_data} ${output_data} ${chunk_size}\
  --spw_range ${spw0} ${spw1} --throw_away_flagged_bls --clobber

chunk_data_files.py ${datafiles} ${input_data} ${output_data} ${chunk_size}\
  --spw_range ${spw0} ${spw1} --throw_away_flagged_bls --clobber

# if no unflagged data, skip the rest.
if [ -e "${output_data}" ]
then

  # chuck data diff files.
  echo chunk_data_files.py ${datafiles_diff} ${input_data_diff} ${output_data_diff} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --throw_away_flagged_bls --clobber

  chunk_data_files.py ${datafiles_diff} ${input_data_diff} ${output_data_diff} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --throw_away_flagged_bls --clobber

  # chunk the calibration files.
  echo chunk_cal_files.py ${calfiles} ${input_cal} ${output_cal} ${chunk_size}\
   --spw_range ${spw0} ${spw1} --clobber

  chunk_cal_files.py ${calfiles} ${input_cal} ${output_cal} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --clobber


  # chunk auto sum files.
  echo chunk_data_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --throw_away_flagged_bls --clobber

  chunk_data_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --throw_away_flagged_bls --clobber

  # chunk auto diff files.
  echo chunk_data_files.py ${autofiles_diff} ${input_auto_diff} ${output_auto_diff} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --throw_away_flagged_bls --clobber

  chunk_data_files.py ${autofiles_diff} ${input_auto_diff} ${output_auto_diff} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --throw_away_flagged_bls --clobber
else
  echo "${output_data} does not exist!"
fi
