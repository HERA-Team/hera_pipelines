#! /bin/bash
set -e

# This script was commented (documented), edited, and cleaned with the help of Claude Opus 4.8.

# This script ensures a flat-sky FT-of-beam HDF5 (one per polarization) exists
# in the cache. If a matching file is already present in any of the cache
# search dirs, the computation is skipped; otherwise it is computed locally
# and written to the cache_out dir. Output schema is compatible with
# hera_pspec.uvwindow.FTBeam.from_file.
#
# Args (passed positionally from the toml [COMPUTE_FT_BEAM] section):
#   1 - {basename}       : makeflow-supplied per-baseline file path; UNUSED
#                          (this task does not depend on input data, only on
#                          params) but accepted for makeflow compatibility
#   2 - beam_file        : path to UVBeam .fits / .beamfits sim
#   3 - pol              : 'pI', 'xx', 'yy', etc.
#   4 - freq_min_hz      : lower edge of the FT-beam freq grid (Hz)
#   5 - freq_max_hz      : upper edge of the FT-beam freq grid (Hz, exclusive)
#   6 - nfreq            : number of channels
#   7 - mapsize          : Cartesian flat-sky map half-width
#   8 - npix             : pixels per side in the Cartesian projection (odd)
#   9 - cache_dirs       : colon-separated search list (PATH-style)
#  10 - cache_out        : directory to write fresh outputs to
#  11 - force_recompute  : "true" or "false"

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# arg 1 ({basename}) is intentionally ignored.
beam_file=${2}
pol=${3}
freq_min_hz=${4}
freq_max_hz=${5}
nfreq=${6}
mapsize=${7}
npix=${8}
cache_dirs=${9}
cache_out=${10}
force_recompute=${11}

force_flag=""
if [ "${force_recompute}" = "true" ]; then
    force_flag="--force-recompute"
fi

cmd="python ${src_dir}/compute_ft_beam.py \
    --beam-file ${beam_file} \
    --pol ${pol} \
    --freq-min-hz ${freq_min_hz} \
    --freq-max-hz ${freq_max_hz} \
    --nfreq ${nfreq} \
    --mapsize ${mapsize} \
    --npix ${npix} \
    --cache-dirs ${cache_dirs} \
    --cache-out ${cache_out} \
    ${force_flag}"

echo $cmd
eval $cmd

echo "Finished compute_ft_beam.py for pol=${pol} at $(date)"
