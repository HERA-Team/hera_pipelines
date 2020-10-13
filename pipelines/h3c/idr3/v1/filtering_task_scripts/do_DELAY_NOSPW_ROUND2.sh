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
fn_in_even=zen.${jd}.even.${label}.${data_ext}
fn_in_odd=${fn_in_even/even/odd}
auto_file=${fn%.uvh5}.${label}.calibrated.autos.uvh5
auto_file_even=${auto_file/sum/odd}
auto_file_odd=${auto_file/sum/odd}
auto_even_filled_out=${fn%.uvh5}.${label}.foreground_filtered_auto_filled.uvh5
auto_even_filled_out=${auto_even_filled_out/sum/even}
auto_even_res_out=${fn%.uvh5}.${label}.foreground_filtered_auto_res.uvh5
auto_even_res_out=${auto_even_res_out/sum/even}
auto_odd_filled_out=${auto_even_filled_out/even/odd}
auto_odd_res_out=${auto_even_res_out/even/odd}


fn_res_even=zen.${jd}.even.${label}.foreground_filtered_res.${data_ext}
fn_res_odd=${fn_res_even/even/odd}
fn_filled_even=zen.${jd}.even.${label}.foreground_filtered_filled.${data_ext}
fn_filled_odd=${fn_filled_even/even/odd}


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


# even files
echo dpss_delay_filter_run.py ${fn_in_even} --calfile ${calfile} \
  --res_outfilename ${fn_res_even} --clobber --skip_flagged_edges \
  --filled_outfilename ${fn_filled_even} \
  --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}

dpss_delay_filter_run.py ${fn_in_even} --calfile ${calfile} \
    --res_outfilename ${fn_res_even} --clobber --skip_flagged_edges \
    --filled_outfilename ${fn_filled_even} \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}

# odd files
echo dpss_delay_filter_run.py ${fn_in_odd} --calfile ${calfile} \
  --res_outfilename ${fn_res_odd} --clobber --skip_flagged_edges \
  --filled_outfilename ${fn_filled_odd} \
  --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}

dpss_delay_filter_run.py ${fn_in_odd} --calfile ${calfile} \
    --res_outfilename ${fn_res_odd} --clobber --skip_flagged_edges \
    --filled_outfilename ${fn_filled_odd} \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}

# auto file
echo dpss_delay_filter_run.py ${auto_file} --calfile ${calfile} \
  --res_outfilename ${auto_res_out} --clobber --skip_flagged_edges \
  --filled_outfilename ${auto_filled_out} \
  --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}

dpss_delay_filter_run.py ${auto_file} --calfile ${calfile} \
    --res_outfilename ${auto_res_out} --clobber --skip_flagged_edges \
    --filled_outfilename ${auto_filled_out} \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}
