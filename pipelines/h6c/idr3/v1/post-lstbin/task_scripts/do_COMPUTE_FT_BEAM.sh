#! /bin/bash
set -e

# This script ensures a flat-sky FT-of-beam HDF5 (one per polarization) exists
# in the cache, computed on the frequency channels of the merged time-averaged
# pspec file, via the `pspec compute-ft-beam` CLI command from hera_pspec.
# If a matching file is already present in any of the cache dirs the
# computation is skipped. Output schema is compatible with
# hera_pspec.uvwindow.FTBeam.from_file.
#
# Args (passed positionally from the toml [COMPUTE_FT_BEAM] section):
#   1 - {basename}       : per-baseline file path (e.g.
#                          zen.LST.baseline.0_0.sum.FR0filt.uvh5); the merged
#                          tavg-pspec path is derived from it the same way
#                          do_MERGE_SINGLE_BASELINE_FILES.sh does.
#   2 - beam_file        : path to UVBeam .fits / .beamfits sim
#   3 - pol              : 'pI', 'xx', 'yy', etc.
#   4 - label            : instrument/beam label baked into the output
#                          filename (e.g. "HERA_Vivaldi")
#   5 - mapsize          : Cartesian flat-sky map half-width
#   6 - npix             : pixels per side in the Cartesian projection (odd)
#   7 - cache_dirs       : colon-separated cache search list (PATH-style)
#   8 - out_dir          : directory to write fresh outputs to
#   9 - force_recompute  : "true" or "false"

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Locate the merged tavg pspec file produced by MERGE_SINGLE_BASELINE_FILES
# (see do_COMPUTE_WINDOW_FUNCTIONS.sh for the naming rationale).
fn=${1}
outdir=$(cd "$(dirname "$fn")" && pwd)
basename=$(basename "$fn")
suffix="${basename#*.[0-9]*_[0-9]*.}"          # e.g. sum.FR0filt.uvh5
tavg_pspec_file="${outdir}/baselines_merged.${suffix%.uvh5}.tavg.pspec.h5"
if [ ! -f "${tavg_pspec_file}" ]; then
    candidates=("${outdir}"/baselines_merged.*.tavg.pspec.h5)
    if [ -f "${candidates[0]}" ]; then
        tavg_pspec_file="${candidates[0]}"
        echo "[do_COMPUTE_FT_BEAM] Constructed name not found; using ${tavg_pspec_file}"
    else
        echo "ERROR: No baselines_merged.*.tavg.pspec.h5 found in ${outdir}." >&2
        exit 1
    fi
fi

beam_file=${2}
pol=${3}
label=${4}
mapsize=${5}
npix=${6}
cache_dirs=${7}
out_dir=${8}
force_recompute=${9}

force_flag=""
if [ "${force_recompute}" = "true" ]; then
    force_flag="--force-recompute"
fi

cmd="pspec compute-ft-beam \
    ${beam_file} ${pol} ${tavg_pspec_file} \
    --label ${label} \
    --group stokespol \
    --name time_and_interleave_averaged \
    --mapsize ${mapsize} \
    --npix ${npix} \
    --search-dirs ${cache_dirs//:/ } \
    --out-dir ${out_dir} \
    ${force_flag}"

echo $cmd
eval $cmd

echo "Finished pspec compute-ft-beam for pol=${pol} at $(date)"
