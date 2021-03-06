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
# 5 - spw0 lower channel to process.
# 6 - spw1 upper channel to process.
# 7 - tol level to subtract foregrounds too
# 8 - standoff delay standoff in ns for filtering window.
# 9 - cache_dir, directory to store cache files in.
fn="${1}"
data_ext="${2}"
calibration="${3}"
label="${4}"
spw0="${5}"
spw1="${6}"
tol="${7}"
standoff="${8}"
cache_dir="${9}"
# get julian day from file name
jd=$(get_jd $fn)
# generate output file name
fn_out=${fn%.uvh5}.${label}.foreground_filtered.${data_ext}
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

fn_in=${fn%.uvh5}.${label}.${data_ext}


echo dayenu_delay_filter_run.py ${fn_in} --calfile ${calfile} \
  --res_outfilename ${fn_out} --clobber --spw_range ${spw0} ${spw1} --trim_edges \
  --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} #--write_cache --read_cache

dayenu_delay_filter_run.py ${fn_in} --calfile ${calfile} \
    --res_outfilename ${fn_out} --clobber --spw_range ${spw0} ${spw1} --trim_edges \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} #--write_cache --read_cache
