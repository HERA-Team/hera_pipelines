#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2- label
# 3 - tol level to subtract foregrounds too
# 4 - standoff delay standoff in ns for filtering window.
# 5 - min_dly to filter to
# 6 - directory to write cache files
# 7 - filtering mode.
# 8 - number of baselines to load at once for partial i/o
# 9 - spectral windows to perform delay filtering on.

fn="${1}"
label="${2}"
tol="${3}"
standoff="${4}"
min_dly="${5}"
cache_dir="${6}"
nbl_per_load="${7}"
spw_ranges="${8}"
# get julian day from file name

jd=$(get_jd $fn)
int_jd=${jd:0:7}

# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi

sd="sum"

fn_in=zen.${jd}.${sd}.${label}.chunked.uvh5
#fn_in=zen.${jd}.${sd}.${label}.red_avg.chunked.uvh5
fn_cln=zen.${jd}.${sd}.${label}.chunked.foreground_model.uvh5
#fn_cln=zen.${jd}.${sd}.${label}.red_avg.chunked.foreground_model.uvh5

if [ -e "${fn_in}" ]
then
  echo delay_filter_run.py ${fn_in}  \
    --clobber \
    --CLEAN_outfilename ${fn_cln} \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}  \
    --min_dly ${min_dly}  --mode dpss_leastsq --filter_spw_ranges ${spw_ranges}
  delay_filter_run.py ${fn_in}  \
    --clobber  \
    --CLEAN_outfilename ${fn_cln} \
    --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}  \
    --min_dly ${min_dly}  --mode dpss_leastsq --filter_spw_ranges ${spw_ranges}
else
  echo "${fn_in} does not exist!"
fi
