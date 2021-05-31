#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

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
include_diffs="${2}"
label="${3}"
tol="${4}"
standoff="${5}"
min_dly="${6}"
cache_dir="${7}"
filter_mode="${8}"
nbl_per_load="${9}"
# get julian day from file name

jd=$(get_jd $fn)
int_jd=${jd:0:7}

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

if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi


for sd in ${sumdiff[@]}
do
    fn_in=zen.${jd}.${sd}.${label}.chunked.uvh5
    fn_out=zen.${jd}.${sd}.${label}.foreground_filled.uvh5
    fn_cln=zen.${jd}.${sd}.${label}.foreground_model.uvh5
    fn_res=zen.${jd}.${sd}.${label}.foreground_res.uvh5
    if [ -e "${fn_in}" ]
    then
      if [ "${filter_mode}" == "DPSS" ]
      then
        echo delay_filter_run.py ${fn_in}  \
          --filled_outfilename ${fn_out} --clobber --include_flags_in_model \
          --res_outfilename ${fn_res} --CLEAN_outfilename ${fn_cln} \
          --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}  \
          --min_dly ${min_dly}  --mode dpss_leastsq
        delay_filter_run.py ${fn_in}  \
          --filled_outfilename ${fn_out} --clobber  --include_flags_in_model \
          --res_outfilename ${fn_res} --CLEAN_outfilename ${fn_cln} \
          --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff}  \
          --min_dly ${min_dly}  --mode dpss_leastsq
      elif [ "${filter_mode}" == "CLEAN" ]
      then
        npad=$((${spw1}-${spw0}))
        echo delay_filter_run.py ${fn_in}  \
        --filled_outfilename ${fn_out} --clobber --include_flags_in_model \
        --res_outfilename ${fn_res} --CLEAN_outfilename ${fn_cln} \
        --tol ${tol} --standoff ${standoff}  \
        --min_dly ${min_dly} --edgecut_low ${npad} --edgecut_hi ${npad} --zeropad ${npad} --mode clean

        delay_filter_run.py ${fn_in} \
        --filled_outfilename ${fn_out} --clobber --include_flags_in_model \
        --res_outfilename ${fn_res} --CLEAN_outfilename ${fn_cln} \
        --tol ${tol} --standoff ${standoff}  \
        --min_dly ${min_dly} --edgecut_low ${npad} --edgecut_hi ${npad} --zeropad ${npad} --mode clean
      fi
    else
      echo "${fn_in} does not exist!"
    fi
  done
