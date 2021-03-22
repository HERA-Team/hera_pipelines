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
label="${2}"
grpstr="${3}"
beam_file="${4}"
spw_ranges="${5}"
pol_pairs="${6}"

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`

spacer=" "
tilde="~"
#replace tilde with space character in spw_ranges and pol-pairs.
spw_ranges=${spw_ranges/${tilde}/${spacer}}
pol_pairs=${pol_pairs/${tilde}/${spacer}}
# form power spectrum between even and odd data sets with offset times.
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # power spectra of cross-talk filtered data.
  input=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.tavg.uvh5
  output=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.tavg.pspec.h5
  if [ -e "${input}" ]
  then
      # average all times incoherently
      echo pspec_run.py ${input} ${output}\
        --overwrite\
        --dset_pairs '0 1' --pol_pairs '${pol_pairs}'\
        --Jy2mK --beam ${beam_file} --exclude_permutations\
        --file_type uvh5  --exclude_auto_bls\
        --taper bh --spw_ranges '${spw_ranges}' --broadcast_dset_flags

        pspec_run.py ${input} ${output}\
          --overwrite\
          --dset_pairs '0 1' --pol_pairs '${pol_pairs}'\
          --Jy2mK --beam ${beam_file} --exclude_permutations\
          --file_type uvh5  --exclude_auto_bls\
          --taper bh --spw_ranges '${spw_ranges}' --broadcast_dset_flags

    else
      echo "${even_file} does not exist!"
    fi


 auto_file=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.tavg.uvh5

  if [ -e "${auto_file}" ]
  then
   output=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.tavg.pspec.h5
   echo pspec_run.py ${auto_file} ${output}\
     --overwrite\
     --dset_pairs '0 1' --pol_pairs '${pol_pairs}'\
     --Jy2mK --beam ${beam_file}\
     --file_type uvh5 --fullband_filter --include_autocorrs\
     --taper bh --broadcast_dset_flags --spw_ranges '${spw_ranges}'\
     --exclude_cross_bls --interleave_times


   pspec_run.py ${auto_file} ${output}\
     --overwrite\
     --dset_pairs '0 1' --pol_pairs '${pol_pairs}'\
     --Jy2mK --beam ${beam_file}\
     --file_type uvh5 --fullband_filter --include_autocorrs\
     --taper bh --broadcast_dset_flags --spw_ranges '${spw_ranges}'\
     --exclude_cross_bls --interleave_times

  else
     echo "${auto_file} does not exist!"
  fi
done
