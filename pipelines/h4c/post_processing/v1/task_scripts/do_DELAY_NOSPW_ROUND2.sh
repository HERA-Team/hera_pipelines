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
calibration="${3}"
label="${4}"
tol="${5}"
standoff="${6}"
cache_dir="${7}"
# get julian day from file name
jd=$(get_jd $fn)
# generate output file name
fn_in_odd=${fn_in_even/even/odd}
auto_file=${fn%.uvh5}.${label}.autos.calibrated.uvh5
auto_file_even=${auto_file/sum/odd}
auto_file_odd=${auto_file/sum/odd}
auto_even_CLEAN_out=${fn%.uvh5}.${label}.foreground_filtered_auto_CLEAN.uvh5
auto_even_CLEAN_out=${auto_even_CLEAN_out/sum/even}
auto_even_res_out=${fn%.uvh5}.${label}.foreground_filtered_auto_res.uvh5
auto_even_res_out=${auto_even_res_out/sum/even}
auto_odd_CLEAN_out=${auto_even_CLEAN_out/even/odd}
auto_odd_res_out=${auto_even_res_out/even/odd}





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
parities=("even" "odd")
for parity in ${parities[@]}
do
  fn_in=zen.${jd}.${parity}.${label}.${data_ext}
  fn_res=zen.${jd}.${parity}.${label}.foreground_res.${data_ext}
  fn_model=zen.${jd}.${parity}.${label}.foreground_model.${data_ext}
  auto_in=zen.${jd}.${parity}.${label}.autos.calibrated.uvh5
  auto_res=zen.${jd}.${parity}.${label}.auto.foreground_model.uvh5
  auto_filled=zen.${jd}.${parity}.${label}.auto.foreground_filled.uvh5
  if [ -e "${fn_in}" ]
  then
  echo dpss_delay_filter_run.py ${fn_in} --calfile ${calfile} \
    --res_outfilename ${fn_res} --clobber --skip_flagged_edges \
    --CLEAN_outfilename ${fn_model} \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose

  dpss_delay_filter_run.py ${fn_in} --calfile ${calfile} \
    --res_outfilename ${fn_res} --clobber --skip_flagged_edges \
    --CLEAN_outfilename ${fn_model} \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose

    # auto file
    echo dpss_delay_filter_run.py ${auto_in} --calfile ${calfile} \
      --res_outfilename ${auto_res} --clobber --skip_flagged_edges \
      --filled_outfilename ${auto_filled} \
      --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose

    dpss_delay_filter_run.py ${auto_in} --calfile ${calfile} \
      --res_outfilename ${auto_res} --clobber --skip_flagged_edges \
      --filled_outfilename ${auto_filled} \
      --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose
  else
    echo "${fn_in} does not exist!"
  fi
done
