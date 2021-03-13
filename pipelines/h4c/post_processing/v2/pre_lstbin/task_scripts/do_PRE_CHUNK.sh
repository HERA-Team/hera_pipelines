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
fn_diff=${fn/sum/diff}
input_data=zen.${jd}.sum.${data_ext}
output_data=zen.${jd}.sum.${label}.chunked.${data_ext}
input_data_diff=${input_data/sum/diff}
output_data_diff=${output_data/sum/diff}

tmp_sum=zen.${jd}.sum.${label}.chunked.uvh5
tmp_diff=zen.${jd}.diff.${label}.chunked.uvh5


input_auto=zen.${jd}.sum.autos.uvh5
output_auto=zen.${jd}.sum.${label}.autos.chunked.uvh5
input_auto_diff=${input_auto/sum/diff}
output_auto_diff=${output_auto/sum/diff}


input_cal=zen.${jd}.sum.${cal_ext}
output_cal=zen.${jd}.sum.${label}.chunked.${cal_ext}

# chunk the calibration files.
calfiles=`echo zen.${int_jd}.*.sum.${cal_ext}`
echo chunk_cal_files.py ${calfiles} ${input_cal} ${output_cal} ${chunk_size}\
 --spw_range ${spw0} ${spw1} --clobber

chunk_cal_files.py ${calfiles} ${input_cal} ${output_cal} ${chunk_size}\
  --spw_range ${spw0} ${spw1} --clobber

autofiles=`echo zen.${int_jd}.*.sum.autos.uvh5`
echo chunk_data_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
  --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn

chunk_data_files.py ${autofiles} ${input_auto} ${output_auto} ${chunk_size}\
  --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn

# chunk auto diff files.
autofiles_diff=`echo zen.${int_jd}.*.diff.autos.uvh5`
echo chunk_data_files.py ${autofiles_diff} ${input_auto_diff} ${output_auto_diff} ${chunk_size}\
  --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn

chunk_data_files.py ${autofiles_diff} ${input_auto_diff} ${output_auto_diff} ${chunk_size}\
  --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn


parities=("0" "1")
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  for parity in ${parities[@]}
  do
    data_extp=${data_ext/.uvh5/.${parity}.uvh5}
    input_file=zen.${jd}.${sd}.${label}.${data_extp}
    input_files=`echo zen.${int_jd}.*.${sd}.${label}.${data_extp}`
    output_file=zen.${jd}.${sd}.${label}.chunked.${data_extp}
    echo chunk_data_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
    --clobber --polarizations ee nn
    chunk_data_files.py ${input_files} ${input_file} ${output_file} ${chunk_size}\
    --clobber --polarizations ee nn
  done
done

if [ -e "${input_data}" ]
then
# chunk auto sum files.
datafiles=`echo zen.${int_jd}.*.sum.${data_ext}`
  # chuck data diff files.
# chunk data sum files.
echo chunk_data_files.py ${datafiles} ${input_data} ${output_data} ${chunk_size}\
  --clobber --polarizations ee nn

chunk_data_files.py ${datafiles} ${input_data} ${output_data} ${chunk_size}\
  --clobber --polarizations ee nn
fi

# if no unflagged data, skip the rest.
if [ -e "${output_data}" ]
then
  datafiles_diff=`echo zen.${int_jd}.*.diff.${data_ext}`
  echo chunk_data_files.py ${datafiles_diff} ${input_data_diff} ${output_data_diff} ${chunk_size}\
    --clobber --polarizations ee nn

  chunk_data_files.py ${datafiles_diff} ${input_data_diff} ${output_data_diff} ${chunk_size}\
    --clobber --polarizations ee nn

fi
