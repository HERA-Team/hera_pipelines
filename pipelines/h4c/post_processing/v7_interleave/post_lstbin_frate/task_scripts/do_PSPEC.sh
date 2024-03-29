#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


fn="${1}"
include_diffs="${2}"
label="${3}"
beam_file_stem="${4}"
spw_ranges="${5}"
ninterleave="${6}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
fi



if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi

exts=("frf" "foreground_filled.xtalk_filtered.chunked" )


#pol_pair_list=("XX~XX,YY~YY" "pI~pI")
#pol_label_lis=("" "_pstokes")
#polnums=(0 1)
pol_pair_list=("pI~pI")
pol_label_list=("_pstokes")
polnums=(0)
# Create dset_pairs string.
dset_pairs_str=""
for ((interleave_1=0; interleave_1 < ${ninterleave}; interleave_1++))
do
    for ((interleave_2=0; interleave_2 < ${ninterleave}; interleave_2++))
    do
	if [ $interleave_1 -gt 0 ] || [ $interleave_2 -gt 0 ]
	then
	    dset_pairs_str="${dset_pairs_str},${interleave_1}~${interleave_2}"
	else
	    dset_pairs_str="${interleave_1}~${interleave_2}"
	fi
        echo ${dset_pairs_str}
    done
done

for sd in ${sumdiff[@]}
do
  for ext in ${exts[@]}
  do
    for polnum in ${polnums[@]}
    do
      pol_pairs=${pol_pair_list[$polnum]}
      pol_label=${pol_label_list[$polnum]}
      beam_file=${beam_file_stem}${pol_label}.fits
      # power spectra of cross-talk filtered data.
      # Generate list of dsets (interleaves).
      inputs=""
      inputs_exist="true"
      for ((interleave=0; interleave < ${ninterleave}; interleave++))
      do
	  input="zen.${jd}.${sd}.${label}.${ext}${pol_label}.tavg.interleave_${interleave}.uvh5"
	  if [ ! -e "${input}" ]
	  then
	     inputs_exist="false"
	     echo "${input} does not exist!"
	  fi
	  inputs="${inputs} ${input}"
      done
      if [ ${inputs_exist} = "true" ]
      then
          output=zen.${jd}.${sd}.${label}.${ext}${pol_label}.tavg.pspec.h5
          # average all times incoherently
	  cmd="pspec_run.py ${inputs} ${output}\
            --overwrite --dset_pairs ${dset_pairs_str}\
            --pol_pairs ${pol_pairs} --verbose\
            --Jy2mK --beam ${beam_file} --exclude_permutations\
            --file_type uvh5 --xant_flag_thresh 1.1\
            --taper bh --spw_ranges ${spw_ranges}"
	   echo ${cmd}
	   ${cmd}
            if [ "${ext}" = "foreground_filled.xtalk_filtered.chunked" ]
            then
              # auto power spectra
		output=zen.${jd}.${sd}.${label}.autos.${ext}${pol_label}.tavg.pspec.h5
	        cmd="pspec_run.py ${inputs} ${output}\
                --overwrite --dset_pairs ${dset_pairs_str}\
                --pol_pairs ${pol_pairs} --verbose\
                --Jy2mK --beam ${beam_file}\
                --file_type uvh5 --include_autocorrs --xant_flag_thresh 1.1\
                --taper bh --broadcast_dset_flags --spw_ranges ${spw_ranges}\
                --exclude_cross_bls --exclude_crosscorrs"
	        echo ${cmd}
	      ${cmd}
          fi
      else
        echo "${input} does not exist!"
      fi
    done
  done
done
