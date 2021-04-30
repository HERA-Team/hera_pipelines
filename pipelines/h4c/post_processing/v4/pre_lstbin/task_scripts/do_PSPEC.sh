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
beam_file="${3}"
spw_ranges="${4}"
pol_pairs="${5}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

spacer=" "
tilde="~"
#replace tilde with space character in spw_ranges and pol-pairs.
echo ${spw_ranges}
echo ${pol_pairs}
#spw_ranges=${spw_ranges//${tilde}/${spacer}}
#pol_pairs=${pol_pairs//${tilde}/${spacer}}
#spw_ranges=${spw_ranges//,/, }
#pol_pairs=${pol_pairs//,/, }
#spw_ranges="'$spw_ranges'"
#pol_pairs="'$pol_pairs'"
# form power spectrum between even and odd data sets with offset times.
#pol_pairs="ee~ee,nn~nn"
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  # power spectra of cross-talk filtered data.
  input=zen.${jd}.${sd}.${label}.xtalk_filtered.tavg.uvh5
  if [ -e "${input}" ]
  then
      output=zen.${jd}.${sd}.${label}.xtalk_filtered.tavg.pspec.h5
      # average all times incoherently
      echo pspec_run.py ${input} ${output}\
        --overwrite\
        --pol_pairs ${pol_pairs} --verbose\
        --Jy2mK --beam ${beam_file} --exclude_permutations\
        --file_type uvh5  --exclude_auto_bls --xant_flag_thresh 1.1\
        --taper bh --spw_ranges ${spw_ranges} --broadcast_dset_flags

        pspec_run.py ${input} ${output}\
          --overwrite\
          --pol_pairs ${pol_pairs} --verbose\
          --Jy2mK --beam ${beam_file} --exclude_permutations\
          --file_type uvh5  --exclude_auto_bls --xant_flag_thresh 1.1\
          --taper bh --spw_ranges ${spw_ranges} --broadcast_dset_flags

        # auto power spectra
        output=zen.${jd}.${sd}.${label}.autos.foreground_filled.tavg.pspec.h5
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
