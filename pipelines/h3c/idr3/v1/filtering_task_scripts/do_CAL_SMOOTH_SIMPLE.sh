#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
### cal smoothing parameters - see hera_cal.smooth_cal for details
# 2 - freq_scale
# 3 - time_threshold
# 4 - freq_threshold
# 5 - ant_threshold
# 6 - string for xrfi flag files to use. Provide none if no external flag files are to be used.
# 7 - spw range lower bound
# 8 - spw rnage upper bound
# 9 - output label for cal files.
# 10 - flagging yaml
# 11 - lst_blacklists

fn="${1}"
freq_scale="${2}"
time_threshold="${3}"
freq_threshold="${4}"
ant_threshold="${5}"
flag_files="${6}"
flag_ext="${7}"
spw_range0="${8}"
spw_range1="${9}"
label="${10}"
yaml_dir="${11}"
lst_blacklists="${@:12}"

# get list of all calfiles for a day
jd=$(get_jd $fn)
int_jd=${jd:0:7}
calfiles=`echo zen.${int_jd}.*.abs.calfits`

# make the name of this calfits file for --run_if_first option
this_calfile=`echo ${fn%.*}.abs.calfits`

# get yaml file
flag_yaml=${yaml_dir}/${int_jd}.yaml

# get the list of external cal files.
if [ "${flag_files}" == "none"]
then
  if [ "${flag_ext}" != "none" ]
  then
    flag_files=`echo zen.${int_jd}.*.stage_1_xrfi/*${flag_ext}.h5`
  else
    flag_files="none"
  fi
fi

echo smooth_cal_timeavg_run.py ${calfiles} --infile_replace .abs. --outfile_replace .${label}.smooth_abs. --clobber \
                  --pick_refant --run_if_first ${this_calfile} --lst_blacklists ${lst_blacklists} --freq_scale ${freq_scale} \
                  --freq_threshold ${freq_threshold} --factorize_flags \
                  --time_threshold ${time_threshold} --ant_threshold ${ant_threshold} --verbose \
                  --flag_file_list ${flag_files} --spw_range ${spw_range0} ${spw_range1} \
                  --a_priori_flags_yaml ${flag_yaml}

smooth_cal_timeavg_run.py ${calfiles} --infile_replace .abs. --outfile_replace .${label}.smooth_abs. --clobber \
                  --pick_refant --run_if_first ${this_calfile} --lst_blacklists ${lst_blacklists} --freq_scale ${freq_scale} \
                  --freq_threshold ${freq_threshold} --factorize_flags \
                  --time_threshold ${time_threshold} --ant_threshold ${ant_threshold} --verbose \
                  --flag_file_list ${flag_files} --spw_range ${spw_range0} ${spw_range1} \
                  --a_priori_flags_yaml ${flag_yaml}
