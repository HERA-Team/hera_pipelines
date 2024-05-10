#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
label="${2}"
tol="${3}"
spw_ranges="${4}"
prefilter_zero_frate="${5}"
ninterleave="${6}"
#clobber="true"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  int_jd="LST"
  jd="LST.${jd}"
fi


# split up spw ranges.
spw_ranges="${spw_ranges//,/$' '}"
# split into array
read -a spw_ranges_arr <<< ${spw_ranges}

if [ "${prefilter_zero_frate}" = "true" ]
then
  pf_arg="--pre_filter_modes_between_lobe_minimum_and_zero"
else
  pf_arg=""
fi


waterfall_files=`echo zen.${int_jd}.*.sum.${label}.frf.waterfall.uvh5`
if echo x"$waterfall_files" | grep '*' > /dev/null; then
		echo "No waterfall files exist with ${jd}. This is probably because there are more times than baseline groups."
else
    echo ${ilabel}
    # Calculate FRF cov
    fn_out=zen.${jd}.sum.${label}.frf.tavg.cov.interleave_${ilabel}.npy
	
    cmd="FRF_noise_cov_run.py ${waterfall_files}  --tol ${tol} \
      --fn_out ${fn_out} --clobber --verbose --spw_range ${spw_range} \
      --ninterleave ${ninterleave} ${pf_arg}"		   
    echo ${cmd}
	${cmd}  
fi
	    

