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
sumfiles=(`echo zen.${int_jd}.*.sum.uvh5`)
difffiles=(`echo zen.${int_jd}.*.diff.uvh5`)
calfiles=(`echo zen.${int_jd}.*.sum.${cal_ext}`)



# get index of filename
for start in "${!sumfiles[@]}"; do
 if [[ "${sumfiles[$start]}" = "${fn}" ]]; then
     break
 fi
done
let "end=${start}+${chunk_size}-1"

if [ "${end}" -gt "${#sumfiles[@]}" ]
then
    end=${#sumfiles[@]}
    let "end=${end}-1"
fi
#echo ${start}
#echo ${end}
for i in $(seq ${start} ${end})
do
  it=${sumfiles[$i]}
  ot=${it/.uvh5/.${data_ext}}
  calfile=${calfiles[$i]}
  echo apply_cal.py ${it} ${ot} --new_cal ${calfile} --clobber --redundant_average --redundant_groups 2 --spw_range ${spw0} ${spw1}
  apply_cal.py ${it} ${ot} --new_cal ${calfile} --clobber --redundant_average --redundant_groups 2 --spw_range ${spw0} ${spw1}

  it=${difffiles[$i]}
  ot=${it/uvh5/${data_ext}}
  echo apply_cal.py ${it} ${ot} --new_cal ${calfile} --clobber --redundant_average --redundant_groups 2 --spw_range ${spw0} ${spw1}
  apply_cal.py ${it} ${ot} --new_cal ${calfile} --clobber --redundant_average --redundant_groups 2 --spw_range ${spw0} ${spw1}
done
