#! /bin/bash
set -e

# This script ensures exact window-function HDF5s exist for every
# (polpair, spw) tuple requested, via the `pspec compute-window-functions`
# CLI command from hera_pspec. If a matching file is already in the WF dirs
# the computation is skipped. The FT-beam path is resolved by re-running
# `pspec compute-ft-beam`, which is a cache hit (instant) when
# COMPUTE_FT_BEAM already ran as a prereq.
#
# Args (passed positionally from the toml [COMPUTE_WINDOW_FUNCTIONS] section):
#   1  - {basename}       : per-baseline file path (e.g.
#                           zen.LST.baseline.0_0.sum.FR0filt.uvh5);
#                           we derive the tavg-pspec path from it the
#                           same way do_MERGE_SINGLE_BASELINE_FILES.sh does.
#   2  - dataset_label    : free-form differentiator baked into the
#                           WF filename (e.g. "131-nights")
#   3  - spws             : comma-separated 0-indexed spectral window
#                           indices (matching hera_pspec and the spwNN in
#                           the WF filenames); kept comma-separated so the
#                           value stays a single makeflow argument
#   4  - polpairs         : comma-separated polpair strings
#   5  - beam_file        : path to UVBeam .fits sim
#   6  - ft_beam_pol      : pol of the FT beam to use
#   7  - ft_beam_label    : instrument/beam label in the FT-beam filename
#   8  - ft_beam_mapsize  : FT-beam Cartesian half-width
#   9  - ft_beam_npix     : FT-beam Cartesian pixels per side
#  10 - ft_beam_cache_dirs: colon-separated FT-beam cache search list
#  11 - wf_dirs           : colon-separated WF search list (existing
#                           products are reused if filenames match)
#  12 - wf_out_dir        : directory to write fresh WF HDF5s
#  13 - workers           : parallel worker processes over (spw, polpair)
#  14 - force_recompute   : "true" or "false"

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Locate the merged tavg pspec file produced by MERGE_SINGLE_BASELINE_FILES.
# We first try the deterministic name derived from {basename}'s suffix --
#   <outdir>/baselines_merged.<suffix-without-.uvh5>.tavg.pspec.h5
# -- and fall back to a glob if that's not present (the MERGE wrapper has
# evolved to add a ".reinpainted" infix on outputs that the input filename
# may not reflect; the glob tolerates either convention).
fn=${1}
outdir=$(cd "$(dirname "$fn")" && pwd)
basename=$(basename "$fn")
suffix="${basename#*.[0-9]*_[0-9]*.}"          # e.g. sum.FR0filt.uvh5
tavg_pspec_file="${outdir}/baselines_merged.${suffix%.uvh5}.tavg.pspec.h5"
if [ ! -f "${tavg_pspec_file}" ]; then
    candidates=("${outdir}"/baselines_merged.*.tavg.pspec.h5)
    if [ -f "${candidates[0]}" ]; then
        if [ ${#candidates[@]} -gt 1 ]; then
            echo "WARNING: multiple merged tavg pspec files in ${outdir}, picking first:" >&2
            printf '  %s\n' "${candidates[@]}" >&2
        fi
        tavg_pspec_file="${candidates[0]}"
        echo "[do_COMPUTE_WINDOW_FUNCTIONS] Constructed name not found; using ${tavg_pspec_file}"
    else
        echo "ERROR: No baselines_merged.*.tavg.pspec.h5 found in ${outdir}." >&2
        echo "       Run MERGE_SINGLE_BASELINE_FILES first, or symlink one in." >&2
        exit 1
    fi
fi

dataset_label=${2}
spws=${3}
polpairs=${4}
beam_file=${5}
ft_beam_pol=${6}
ft_beam_label=${7}
ft_beam_mapsize=${8}
ft_beam_npix=${9}
ft_beam_cache_dirs=${10}
wf_dirs=${11}
wf_out_dir=${12}
workers=${13}
force_recompute=${14}

force_flag=""
if [ "${force_recompute}" = "true" ]; then
    force_flag="--force-recompute"
fi

# Resolve the FT-beam path with the same cache logic as COMPUTE_FT_BEAM
# (cache hit -> instant). This guarantees both tasks agree on the file.
first_cache_dir="${ft_beam_cache_dirs%%:*}"
ft_beam_file=$(pspec compute-ft-beam \
    ${beam_file} ${ft_beam_pol} ${tavg_pspec_file} \
    --label ${ft_beam_label} \
    --group stokespol \
    --name time_and_interleave_averaged \
    --mapsize ${ft_beam_mapsize} \
    --npix ${ft_beam_npix} \
    --search-dirs ${ft_beam_cache_dirs//:/ } \
    --out-dir "${first_cache_dir}" \
    | grep '^FT_BEAM_PATH=' | cut -d= -f2)
echo "[do_COMPUTE_WINDOW_FUNCTIONS] Using FT beam: ${ft_beam_file}"

cmd="pspec compute-window-functions \
    ${tavg_pspec_file} ${ft_beam_file} \
    --group stokespol \
    --name time_and_interleave_averaged \
    --dataset-label ${dataset_label} \
    --spws ${spws//,/ } \
    --polpairs ${polpairs//,/ } \
    --wf-dirs ${wf_dirs//:/ } \
    --out-dir ${wf_out_dir} \
    --workers ${workers} \
    ${force_flag}"

echo $cmd
eval $cmd

echo "Finished pspec compute-window-functions for dataset=${dataset_label}, polpairs=${polpairs}, spws=${spws} at $(date)"
