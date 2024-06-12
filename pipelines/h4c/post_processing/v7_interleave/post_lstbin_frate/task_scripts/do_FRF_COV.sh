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

jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
jd="LST.${jd}"


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

for spw_range in spw_ranges
do
  waterfall_file=`echo zen.${jd}.sum.${label}.frf.spw_range_${spw_range}.waterfall.uvh5`
  if echo x"$waterfall_files" | grep '*' > /dev/null; then
		echo "No waterfall files exist with ${jd}. This is probably because there are more times than baseline groups."
  else
    # Calculate FRF cov
    fn_out=zen.${jd}.sum.${label}.frf.tavg.spw_range_${spw_range}.cov.npy
	
    cmd="FRF_noise_cov_run.py ${waterfall_files}  --tol ${tol} \
      --fn_out ${fn_out} --clobber --verbose --spw_range ${spw_range} \
      --ninterleave ${ninterleave} ${pf_arg}"		   
    echo ${cmd}
	${cmd}  
  fi
done	    

