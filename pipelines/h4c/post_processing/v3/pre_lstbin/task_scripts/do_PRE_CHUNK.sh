#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"
chunk_size="${3}"
spw0="${4}"
spw1="${5}"
yaml_dir="${6}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
# remove staging dir.
stage_dir=staging.${label}.${jd}
rm -rf ${stage_dir}
mkdir ${stage_dir}
ant_flag_yaml=${yaml_dir}/${int_jd}.yaml

sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # stage full baseline files.
  input_files=""
  input_autos=""
  # iterate over files until we reach the specific jd
  visited_fname="false"
  counter=0
  for filename in zen.${int_jd}.*.${sd}.autos.uvh5
  do
    jd_temp=$(get_jd $filename)
    if [ "${jd_temp}" = "${jd}" ]
    then
      visited_fname="true"
    fi
    # If we visited the input filename and the counter is less then chunk size.
    if [[ "${visited_fname}" = "true" && "${counter}" -lt "${chunk_size}" ]]
    then
      # stage data for the JD.
      json_string='{"name-matches": "zen.'"${jd_temp}.${sd}"'.uvh5"}'
      echo librarian stage-files -w local ${stage_dir}  "$json_string"
      librarian stage-files -w local ${stage_dir} "$json_string"
      # concatenate name of staged file to list of files to be fed to file chunker.
      input_files=${input_files}" ${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.uvh5"
      # calibrate file
      cal_file=zen.${jd_temp}.sum.smooth_abs.calfits
      input_file=${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.uvh5
      output_file=${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.uvh5
      echo apply_cal.py --new_cal ${cal_file} --clobber ${input_file} ${output_file}
      apply_cal.py --new_cal ${cal_file} --clobber  ${input_file} ${output_file}

      # calibrate auto file.
      # extract the auto file from staged data in case its missing.
      input_auto=zen.${jd_temp}.${sd}.autos.uvh5
      extract_autos.py ${input_file} ${input_auto} --clobber
      output_auto=zen.${jd_temp}.${sd}.${label}.autos.calibrated.uvh5
      echo apply_cal.py ${input_auto} ${output_auto} --clobber --new_cal ${cal_file}
      apply_cal.py ${input_auto} ${output_auto} --clobber --new_cal ${cal_file}
      input_autos=${input_autos}" ${output_auto}"
      # update counter
      counter=$((${counter} + 1))
    fi
  done
  # chunk staged input baseline files into a single file and throw away flagged antennas.
  input_file=${stage_dir}/${int_jd}/zen.${jd}.${sd}.uvh5
  output_file=zen.${jd}.${sd}.${label}.chunked.uvh5
  echo chunk_data_files.py ${input_files} ${input_file} ${output_file}  ${chunk_size} --spw_range ${spw0} ${spw1} \
  --clobber --polarizations ee nn --throw_away_flagged_bls --ant_flag_yaml ${ant_flag_yaml}
  chunk_data_files.py ${input_files} ${input_file} ${output_file} ${chunk_size} --spw_range ${spw0} ${spw1} \
  --clobber --polarizations ee nn --throw_away_flagged_bls --ant_flag_yaml ${ant_flag_yaml}
  # chunk calibrated auto files into single file and throw away bad antennas
  input_auto=zen.${jd}.${sd}.${label}.autos.calibrated.uvh5
  output_auto=zen.${jd}.${sd}.${label}.autos.chunked.uvh5
  echo chunk_data_files.py ${input_autos} ${input_auto} ${output_auto} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn \
    --throw_away_flagged_bls --ant_flag_yaml ${ant_flag_yaml}
  chunk_data_files.py ${input_autos} ${input_auto} ${output_auto} ${chunk_size}\
    --spw_range ${spw0} ${spw1} --clobber --polarizations ee nn \
    --throw_away_flagged_bls --ant_flag_yaml ${ant_flag_yaml}
  # remove calibrated autos that are not chunked.
  echo rm -rf ${input_autos}
  rm -rf ${input_autos}
done
# remove staged files.
rm -rf ${stage_dir}
