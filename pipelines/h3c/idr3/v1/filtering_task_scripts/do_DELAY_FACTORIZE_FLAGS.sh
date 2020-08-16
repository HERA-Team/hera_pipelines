#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - data extension
# 3 - calibration file
# 4 - extra label for the output file.
# 5 - spw0 lower channel to process.
# 6 - spw1 upper channel to process.
# 7 - tol level to subtract foregrounds too
# 8 - factorization threshold.
# 9 - standoff delay standoff in ns for filtering window.
# 10 - cache_dir, directory to store cache files in.
fn="${1}"
data_ext="${2}"
calibration="${3}"
label="${4}"
spw0="${5}"
spw1="${6}"
tol="${7}"
time_thresh="${8}"
standoff="${9}"
cache_dir="${10}"
# get julian day from file name
jd=$(get_jd $fn)
# generate output file name
fn_out=zen.${jd}.${label}.foreground_filtered_waterfall.${data_ext}
# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi

if [ "${calibration}" != "none" ]
then
  calfiles=`echo zen.${int_jd}.*.sum.smooth_abs.calfits`
else
  calfiles="none"
fi

# list of all foreground filtered files.
data_files=`echo zen.${int_jd}.*.${label}.${data_ext}

echo dayenu_delay_filter_run_baseline_parallelized.py ${fn_in} \
  --res_outfilename ${fn_out} --clobber --spw_range ${spw0} ${spw1} \
  --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --factorize_flags --time_thresh=${time_thresh} \
  --trim_edges --datafilelist ${data_files} --calfile_list ${calfiles}

dayenu_delay_filter_run_baseline_parallelized.py ${fn_in} \
    --res_outfilename ${fn_out} --clobber --spw_range ${spw0} ${spw1} \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --factorize_flags --time_thresh=${time_thresh} \
    --trim_edges --datafilelist ${data_files} --calfile_list ${calfiles}
