#! /bin/bash
set -e
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

#the args are
# 1 - input file name.
# 2 - label
# 3 - path to beam file
# 4 - group string identifier.
# 4 - spw-ranges to use fed as comma separated list with tildes separating upper / lower channels.
# 5 - polarizatios to calculate fed as comma separated list with tildes separating lower / uppper channels.
fn="${1}"
include_diffs="${2}"
label="${3}"
beam_file_stem="${4}"
spw_ranges="${5}"
transfer_filled_flags="${6}"
transfer_res_flags="${7}"

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


if [ "${transfer_res_flags}" == "true" ]
then
  exts=("foreground_filled.res_flags.filled" "foreground_res.filled" "foreground_model.res_flags.filled")
elif [ "${transfer_filled_flags}" == "true" ]
then
  exts=("foreground_filled" "foreground_res.filled_flags" "foreground_model.filled_flags")
fi

pol_pair_list=("XX~XX,YY~YY" "pI~pI")
pol_label_list=("" "_pstokes")
polnums=(0 1)
for sd in ${sumdiff[@]}
do
  for polnum in ${polnums[@]}
  do
    pol_pairs=${pol_pair_list[$polnum]}
    pol_label=${pol_label_list[$polnum]}
    beam_file=${beam_file_stem}${pol_label}.fits
    # power spectra of cross-talk filtered data.
    for ext in ${exts[@]}
    do
      input=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered${pol_label}.tavg.uvh5
      if [ -e "${input}" ]
      then
          output=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered${pol_label}.tavg.pspec.h5
          # average all times incoherently
          echo pspec_run.py ${input} ${output}\
            --overwrite\
            --pol_pairs ${pol_pairs} --verbose\
            --Jy2mK --beam ${beam_file} --exclude_permutations\
            --file_type uvh5 --xant_flag_thresh 1.1\
            --taper bh --spw_ranges ${spw_ranges}

            pspec_run.py ${input} ${output}\
              --overwrite\
              --pol_pairs ${pol_pairs} --verbose\
              --Jy2mK --beam ${beam_file} --exclude_permutations\
              --file_type uvh5  --xant_flag_thresh 1.1\
              --taper bh --spw_ranges ${spw_ranges}

            # auto power spectra
            output=zen.${jd}.${sd}.${label}.autos.${ext}${pol_label}.tavg.pspec.h5
            echo pspec_run.py ${input} ${output}\
              --overwrite\
              --pol_pairs ${pol_pairs} --verbose\
              --Jy2mK --beam ${beam_file}\
              --file_type uvh5 --include_autocorrs --xant_flag_thresh 1.1\
              --taper bh --broadcast_dset_flags --spw_ranges ${spw_ranges}\
              --exclude_cross_bls --exclude_crosscorrs


            pspec_run.py ${input} ${output}\
              --overwrite\
              --pol_pairs ${pol_pairs} --verbose\
              --Jy2mK --beam ${beam_file}\
              --file_type uvh5 --include_autocorrs --xant_flag_thresh 1.1\
              --taper bh --broadcast_dset_flags --spw_ranges ${spw_ranges}\
              --exclude_cross_bls --exclude_crosscorrs
      else
        echo "${input} does not exist!"
      fi
    done
  done
done
