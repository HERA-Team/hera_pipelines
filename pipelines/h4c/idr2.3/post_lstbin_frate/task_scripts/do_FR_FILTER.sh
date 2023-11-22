#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
include_diffs="${2}"
label="${3}"
tol="${4}"
uvbeam="${5}"
percentile_low="${6}"
percentile_high="${7}"
spw_ranges="${8}"
prefilter_zero_frate="${9}"
ninterleave="${10}"
filter_dir="${11}"
file_basename="${12}"
#clobber="true"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
fi

# split up spw ranges.
spw_ranges="${spw_ranges//,/$' '}"
# split into array
read -a spw_ranges_arr <<< ${spw_ranges}

# if cache directory does not exist, make it
if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi

if [ "${prefilter_zero_frate}" = "true" ]
then
  pf_arg="--pre_filter_modes_between_lobe_minimum_and_zero"
else
  pf_arg=""
fi

for sd in ${sumdiff[@]}
do
  fn_in=zen.${jd}.${sd}.${label}.foreground_filled.xtalk_filtered.chunked.uvh5
  for spw in ${!spw_ranges[@]}
  do
    spw_range=${spw_ranges[spw]}
    # pull out tilde delimiter.
    fg_files=`echo zen.*.${sd}.${label}.foreground_filled.xtalk_filtered.chunked.uvh5`
    fn_out=zen.${jd}.${sd}.${label}.frf.spw_range_${spw_range}.waterfall.uvh5
    filter_file="${filter_dir}/${file_basename}${spw}.yaml"
    if [ -e "${fn_in}" ]
    then
      # split up spw_range
      spw_range="${spw_range/\~/ }"
      #if [ "${clobber}" = "true" ] && [ ! -e "${CLEAN_outfilename}" ]
      #  then
      echo tophat_frfilter_run.py ${fg_files}  --tol ${tol} \
      --CLEAN_outfilename ${fn_out} \
      --cornerturnfile ${fn_in} --beamfitsfile ${uvbeam} --percentile_low ${percentile_low} --percentile_high ${percentile_high} --fr_freq_skip 10\
      --clobber --verbose --mode dpss_leastsq --spw_range ${spw_range} --skip_autos --frate_standoff 0.05 --min_frate_half_width 0.15 --ninterleave ${ninterleave} --case "uvbeam" ${pf_arg} --param_file ${filter_file}

      tophat_frfilter_run.py ${fg_files}  --tol ${tol} \
      --CLEAN_outfilename ${fn_out} \
      --cornerturnfile ${fn_in} --beamfitsfile ${uvbeam} --percentile_low ${percentile_low} --percentile_high ${percentile_high} --fr_freq_skip 10\
      --clobber --verbose --mode dpss_leastsq --spw_range ${spw_range} --skip_autos --frate_standoff 0.05 --min_frate_half_width 0.15 --ninterleave ${ninterleave} --case "uvbeam" ${pf_arg} --param_file ${filter_file}
      #fi
    else
      echo "${fn_in} does not exist!"
    fi
  done
done
