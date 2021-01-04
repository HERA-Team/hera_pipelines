#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 3 - calibration file
# 4 - extra label for the output file.
# 5 - tol level to subtract foregrounds too
# 6 - standoff delay standoff in ns for filtering window.
# 7 - cache_dir, directory to store cache files in.
fn="${1}"
data_ext="${2}"
flag_ext="${3}"
labelin="${4}"
label="${5}"
tol="${6}"
standoff="${7}"
min_dly="${8}"
cache_dir="${9}"
pols="${10}"
# get julian day from file name
jd=$(get_jd $fn)
# generate output file name
int_jd=${jd:0:7}
flagfile=zen.${int_jd}.${flag_ext}




# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi

if [ "${calibration}" != "none" ]
then
  calfile=${fn%.uvh5}.${calibration}
else
  calfile="none"
fi
parities=("0" "1")
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # auto file
  auto_in=zen.${jd}.${sd}.${labelin}.autos.calibrated.uvh5
  if [ -e "${auto_in}" ]
  then
    auto_out=zen.${jd}.${sd}.${label}.auto.foreground_filled.uvh5
    echo dpss_delay_filter_run.py ${auto_in} \
      --clobber --skip_flagged_edges \
      --filled_outfilename ${auto_out} --polarizations ${pols} \
      --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose \
      --min_dly ${min_dly} --flag_rms_outliers


    dpss_delay_filter_run.py ${auto_in} \
      --clobber --skip_flagged_edges \
      --filled_outfilename ${auto_out} --polarizations ${pols} \
      --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose \
      --min_dly ${min_dly} --flag_rms_outliers

  else
    echo "${auto_in} does not exist!"
  fi
  for parity in ${parities[@]}
  do
    data_extp=${data_ext/.uvh5/.${parity}.uvh5}
    fn_in=zen.${jd}.${sd}.${labelin}.chunked.${data_extp}
    fn_out=zen.${jd}.${sd}.${label}.foreground_filled.${data_extp}
    fn_res=zen.${jd}.${sd}.${label}.foreground_res.${data_extp}

    if [ -e "${fn_in}" ]
    then
    echo dpss_delay_filter_run.py ${fn_in} \
      --filled_outfilename ${fn_out} --clobber --skip_flagged_edges --res_outfilename ${fn_res}  \
      --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose \
      --external_flags ${flagfile} --polarizations ${pols} --overwrite_data_flags \
      --min_dly ${min_dly} --flag_rms_outliers


    dpss_delay_filter_run.py ${fn_in} \
      --filled_outfilename ${fn_out} --clobber --skip_flagged_edges  --res_outfilename ${fn_res} \
      --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose \
      --external_flags ${flagfile} --polarizations ${pols} --overwrite_data_flags \
      --min_dly ${min_dly} --flag_rms_outliers

    else
      echo "${fn_in} does not exist!"
    fi
  done
done
