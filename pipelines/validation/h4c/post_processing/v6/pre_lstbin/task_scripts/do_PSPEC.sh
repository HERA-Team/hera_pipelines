#! /bin/bash

#-----------------------------------------------------------------------------
# This script computes night power spectra as part of the nightly post
# processing pipeline.
#-----------------------------------------------------------------------------


set -e
# sometimes /tmp gets filled up on NRAO nodes hence this line.
# haven't need to use it recently.
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/
#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

#-----------------------------------------------------------------------------
# ARGUMENTS
# 1) fn: Input filename (string) assumed to contain JD.
# 2) include_diffs: Whether or not to perform analysis on diff files as well as sum files.
#    valid options are "true" or "false".
# 3) label: identifying string label for analysis outputs to set it apart from other
#    runs with different parameters.
# 4) beam_file_stem: string denoting location of beam file to use for normalization.
#    basically the full beam path minus a potential polarizatin post-fix.
#    example: /lustre/aoc/projects/hera/H4C/beams/NF_HERA_Vivaldi_efield_beam_healpix
# 5) spw_ranges: comma seprated list of spw ranges for each pspec denoted by tildes.
#    example: 10~105,150~320,515~615,665~717,770~1090

# ASSUMED INPUTS:
# 1) Xtalk filtered, delay inpainted, time-averaged sum/diff files with
#    pstokes I polarizations with naming format
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered${pol_label}.tavg.uvh5
#    where pol_label can be "_pI" or "" (for XX/YY).
# 2) Beam file with naming convention
#    ${beamfile_stem}${pol_label}.fits

# OUTPUTS:
# 1) sum/diff xtalk filtered, delay inpainted, time-averaged pstokes power spectra
#    with format
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered${pol_label}.tavg.pspec.h5
#
#
#-----------------------------------------------------------------------------



fn="${1}"
include_diffs="${2}"
label="${3}"
beam_file_stem="${4}"
spw_ranges="${5}"



jd=$(get_jd $fn)
int_jd=${jd:0:7}


if [ "${include_diffs}" = "true" ]
then
  sumdiff=("sum" "diff")
else
  sumdiff=("sum")
fi

exts=("foreground_filled")

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
            --taper bh --spw_ranges ${spw_ranges} --broadcast_dset_flags

            pspec_run.py ${input} ${output}\
              --overwrite\
              --pol_pairs ${pol_pairs} --verbose\
              --Jy2mK --beam ${beam_file} --exclude_permutations\
              --file_type uvh5  --xant_flag_thresh 1.1\
              --taper bh --spw_ranges ${spw_ranges} --broadcast_dset_flags

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
