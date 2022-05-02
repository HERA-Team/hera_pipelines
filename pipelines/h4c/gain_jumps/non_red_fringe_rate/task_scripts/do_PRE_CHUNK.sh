#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"
chunk_size="${3}"
spw_ranges="${4}"
yaml_dir="${5}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
# remove staging dir.
stage_dir=staging.${label}.${jd}
rm -rf ${stage_dir}
mkdir ${stage_dir}
mkdir ${stage_dir}/${int_jd}
ant_flag_yaml=${yaml_dir}/${int_jd}.yaml

sd="sum"

# stage full baseline files.
input_files=""
input_autos=""
# iterate over files until we reach the specific jd
visited_fname="false"
counter=0
for filename in zen.${int_jd}.*.sum.smooth_abs.calfits
do
  jd_temp=$(get_jd $filename)
  if [ "${jd_temp}" = "${jd}" ]
  then
    visited_fname="true"
  fi
  # If we visited the input filename and the counter is less then chunk size.
  if [[ "${visited_fname}" = "true" && "${counter}" -lt "${chunk_size}" ]]
  then
    #check if file already exists locally. If it does, move it to staging dir
    if [ -e "zen.${jd_temp}.${sd}.uvh5" ]
    then
      echo cp zen.${jd_temp}.${sd}.uvh5 ${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.uvh5
      cp zen.${jd_temp}.${sd}.uvh5 ${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.uvh5
    else
      # otherwise, download via librarian.
      # stage data for the JD.
      json_string='{"name-matches": "zen.'"${jd_temp}.${sd}"'.uvh5"}'
      echo librarian stage-files -w local ${stage_dir}  "$json_string"
      librarian stage-files -w local ${stage_dir} "$json_string"
    fi
    # concatenate name of staged file to list of files to be fed to file chunker.
    input_files=${input_files}" ${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.uvh5"
    input_files_red=${input_files_red}" ${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.red_avg.uvh5"
    # calibrate file
    cal_file=zen.${jd_temp}.sum.smooth_abs.calfits
    input_file=${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.uvh5
    output_file=${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.uvh5
    output_file_red=${stage_dir}/${int_jd}/zen.${jd_temp}.${sd}.red_avg.uvh5
    # if the diff does not exist, spoof it with the sum file and set
    # all data to zero and all flags to True.
    if [ ! -e "${input_file}" ]
    then
      echo "${input_file} failed to stage. Attempting to rectify this by spoofing with the sum/diff complement."
      if [ ${sd} = "diff" ]
      then
        json_string='{"name-matches": "zen.'"${jd_temp}.sum"'.uvh5"}'
        echo librarian stage-files -w local ${stage_dir}  "$json_string"
        librarian stage-files -w local ${stage_dir} "$json_string"
        cp ${stage_dir}/${int_jd}/zen.${jd_temp}.sum.uvh5 ${input_file}
      else
        json_string='{"name-matches": "zen.'"${jd_temp}.diff"'.uvh5"}'
        echo librarian stage-files -w local ${stage_dir}  "$json_string"
        librarian stage-files -w local ${stage_dir} "$json_string"
        cp ${stage_dir}/${int_jd}/zen.${jd_temp}.diff.uvh5 ${input_file}
      fi
      echo flag_all.py ${input_file} ${input_file}  --clobber --fill_data_with_zeros
      flag_all.py ${input_file} ${input_file} --clobber --fill_data_with_zeros
    fi

    # select spw ranges.
    echo select_spw_ranges.py ${input_file} ${input_file} --spw_ranges ${spw_ranges} --clobber
    select_spw_ranges.py ${input_file} ${input_file} --spw_ranges ${spw_ranges} --clobber

    # Generate redundantly averaged file.
    #echo apply_cal.py --new_cal ${cal_file} --clobber ${input_file} ${output_file_red} --vis_units Jy -redundant_average
    #apply_cal.py --new_cal ${cal_file} --clobber  ${input_file} ${output_file_red} --vis_units Jy --redundant_average

    # apply calibration solutions.
    echo apply_cal.py --new_cal ${cal_file} --clobber ${input_file} ${output_file} --vis_units Jy
    apply_cal.py --new_cal ${cal_file} --clobber  ${input_file} ${output_file} --vis_units Jy


    # update counter
    counter=$((${counter} + 1))
  fi
done
# chunk staged input baseline files into a single file and throw away flagged antennas.
input_file=${stage_dir}/${int_jd}/zen.${jd}.${sd}.uvh5
output_file=zen.${jd}.${sd}.${label}.chunked.uvh5

input_file_red=${stage_dir}/${int_jd}/zen.${jd}.${sd}.red_avg.uvh5
output_file_red=zen.${jd}.${sd}.${label}.red_avg.chunked.uvh5


echo chunk_files.py ${input_files} ${input_file} ${output_file}  ${chunk_size} \
--clobber --polarizations ee nn --throw_away_flagged_ants --ant_flag_yaml ${ant_flag_yaml}
chunk_files.py ${input_files} ${input_file} ${output_file} ${chunk_size} \
--clobber --polarizations ee nn --throw_away_flagged_ants --ant_flag_yaml ${ant_flag_yaml}

#echo chunk_files.py ${input_files_red} ${input_file_red} ${output_file_red}  ${chunk_size} \
#--clobber --polarizations ee nn --throw_away_flagged_ants --ant_flag_yaml ${ant_flag_yaml}
#chunk_files.py ${input_files_red} ${input_file_red} ${output_file_red} ${chunk_size} \
#--clobber --polarizations ee nn --throw_away_flagged_ants --ant_flag_yaml ${ant_flag_yaml}

# remove staged files.
rm -rf ${stage_dir}
