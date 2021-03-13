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
data_ext="${2}"
label="${3}"
tol="${4}"
standoff="${5}"
min_dly="${6}"
cache_dir="${7}"
filter_mode="${8}"
spw0="${9}"
spw1="${10}"
grpstr="${11}"
nbl_per_load="${12}"
pols="${@:13}"
# get julian day from file name
lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`





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
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # auto file
  auto_in=zen.${grpstr}.LST.${lst}.${sd}.autos.uvh5
  if [ -e "${auto_in}" ]
  then
    auto_out=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.foreground_filled.uvh5
    echo dpss_delay_filter_run.py ${auto_in} \
      --clobber --skip_flagged_edges \
      --filled_outfilename ${auto_out} --polarizations ${pols} \
      --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose \
      --min_dly ${min_dly} --flag_rms_outliers --spw_range ${spw0} ${spw1}


    dpss_delay_filter_run.py ${auto_in}  \
      --clobber --skip_flagged_edges \
      --filled_outfilename ${auto_out} --polarizations ${pols} \
      --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose \
      --min_dly ${min_dly} --flag_rms_outliers --spw_range ${spw0} ${spw1}

  else
    echo "${auto_in} does not exist!"
  fi
    fn_in=zen.${grpstr}.LST.${lst}.${sd}.uvh5
    fn_out=zen.${grpstr}.LST.${lst}.${sd}.${label}.foreground_filled.uvh5
    fn_res=zen.${grpstr}.LST.${lst}.${sd}.${label}.foreground_res.uvh5
    if [ -e "${fn_in}" ]
    then
      if [ "${filter_mode}" == "DPSS" ]
      then
        echo dpss_delay_filter_run.py ${fn_in}  \
          --filled_outfilename ${fn_out} --clobber --skip_flagged_edges --res_outfilename ${fn_res}  \
          --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose \
          --polarizations ${pols} \
          --min_dly ${min_dly} --flag_rms_outliers --spw_range ${spw0} ${spw1}
        dpss_delay_filter_run.py ${fn_in}  \
          --filled_outfilename ${fn_out} --clobber --skip_flagged_edges  --res_outfilename ${fn_res} \
          --tol ${tol} --cache_dir ${cache_dir} --standoff ${standoff} --verbose \
          --polarizations ${pols} \
          --min_dly ${min_dly} --flag_rms_outliers --spw_range ${spw0} ${spw1}
      elif [ "${filter_mode}" == "CLEAN" ]
      then
        npad=$((${spw1}-${spw0}))
        echo delay_filter_run.py ${fn_in}  \
        --filled_outfilename ${fn_out} --clobber --res_outfilename ${fn_res}  \
        --tol ${tol} --standoff ${standoff} --verbose \
        --polarizations ${pols} \
        --min_dly ${min_dly} --edgecut_low ${npad} --edgecut_hi ${npad} --zeropad ${npad} --spw_range ${spw0} ${spw1}

        delay_filter_run.py ${fn_in} \
        --filled_outfilename ${fn_out} --clobber --res_outfilename ${fn_res}  \
        --tol ${tol} --standoff ${standoff} --verbose \
        --polarizations ${pols} \
        --min_dly ${min_dly} --edgecut_low ${npad} --edgecut_hi ${npad} --zeropad ${npad} --spw_range ${spw0} ${spw1}
      fi
    else
      echo "${fn_in} does not exist!"
    fi
  done
