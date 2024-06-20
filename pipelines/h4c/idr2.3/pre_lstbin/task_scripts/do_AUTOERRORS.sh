#! /bin/bash

#-----------------------------------------------------------------------------
# This script computes nightly power spectrum error bars.
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
#
#
# ASSUMED INPUTS:
# 1) Xtalk filtered, delay inpainted, time-averaged sum/diff files with
#    pstokes I polarizations with naming format
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered${pol_label}.tavg.uvh5
#    where pol_label can be "_pI" or "" (for XX/YY).
#    these data files must contain autocorrelations that are not xtalk filtered.
# 2) Xtalk filtered, delay inpainted, time averaged sum/diff power spectra with
#    pstokes I polarization naming format
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered${pol_label}.tavg.pspec.h5
# 3) Beam file with naming convention
#    ${beamfile_stem}${pol_label}.fits
#

# OUTPUTS:
# 1) sum/diff xtalk filtered, delay inpainted, time-averaged pstokes power spectra
#    with format
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered${pol_label}.tavg.pspec.h5
#    with autocorrelation derived error bars.
#
#
#-----------------------------------------------------------------------------


fn="${1}"
include_diffs="${2}"
label="${3}"
beamfile_stem="${4}"


jd=$(get_jd $fn)
int_jd=${jd:0:7}
exts=("foreground_filled")
sumdiff=("sum" "diff")
pol_label_list=("" "_pstokes")
for sd in ${sumdiff[@]}
do
  for pol_label in ${pol_label_list[@]}
  do
    beamfile=${beamfile_stem}${pol_label}.fits
    for ext in ${exts[@]}
    do
      psc=zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered${pol_label}.tavg.pspec.h5
      echo ${psc}
      if [ -e "${psc}" ]
      then
        dfile=zen.${jd}.sum.${label}.foreground_filled.xtalk_filtered${pol_label}.tavg.uvh5
        if [ -e "${dfile}" ]
        then
          echo auto_noise_run.py ${psc} ${dfile} ${beamfile} --err_type 'P_N' 'P_SN'
          auto_noise_run.py ${psc} ${dfile} ${beamfile} --err_type 'P_N' 'P_SN'
        fi
      fi
    done
  done
done
