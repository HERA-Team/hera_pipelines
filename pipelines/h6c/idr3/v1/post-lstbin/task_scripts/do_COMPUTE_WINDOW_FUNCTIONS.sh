#! /bin/bash
set -e

# This script was commented (documented), edited, and cleaned with the help of Claude Opus 4.8.

# This script ensures window-function HDF5s exist for every (algo, polpair, spw)
# tuple requested. If a matching file is already in the WF cache, the
# computation is skipped; otherwise it is computed via
# UVPSpec.get_exact_window_functions and written to the cache_out dir.
# Requires that COMPUTE_FT_BEAM has produced (or located) a matching FT-beam
# HDF5 in the FT-beam cache.
#
# Args (passed positionally from the toml [COMPUTE_WINDOW_FUNCTIONS] section):
#   1  - {basename}             : per-baseline file path (e.g.
#                                 zen.LST.baseline.0_0.sum.FR0filt.uvh5);
#                                 we derive the tavg-pspec path from it the
#                                 same way do_MERGE_SINGLE_BASELINE_FILES.sh does.
#   2  - algo                   : "exact" or "with-inpainting"
#   3  - dataset_label          : free-form differentiator baked into the
#                                 WF filename (e.g. "086-nights_redavg-1000ns")
#   4  - bands                  : comma-separated 1-indexed band numbers
#   5  - polpairs               : comma-separated polpair strings
#   6  - taper                  : taper used in pspec (provenance only)
#   7  - beam_file              : path to UVBeam .fits sim
#   8  - ft_beam_pol            : pol of the FT-beam to use
#   9  - ft_beam_freq_min_hz    : FT-beam freq grid lower edge (Hz)
#  10 - ft_beam_freq_max_hz     : FT-beam freq grid upper edge (Hz, exclusive)
#  11 - ft_beam_nfreq           : FT-beam channels
#  12 - ft_beam_mapsize         : FT-beam Cartesian half-width
#  13 - ft_beam_npix            : FT-beam Cartesian pixels per side
#  14 - ft_beam_cache_dirs      : colon-separated FT-beam cache search list
#  15 - wf_dirs                 : colon-separated WF search list (existing
#                                 products are reused if filenames match)
#  16 - wf_out_dir              : directory to write fresh WF HDF5s
#  17 - force_recompute         : "true" or "false"

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

algo=${2}
dataset_label=${3}
bands=${4}
polpairs=${5}
taper=${6}
beam_file=${7}
ft_beam_pol=${8}
ft_beam_freq_min_hz=${9}
ft_beam_freq_max_hz=${10}
ft_beam_nfreq=${11}
ft_beam_mapsize=${12}
ft_beam_npix=${13}
ft_beam_cache_dirs=${14}
wf_dirs=${15}
wf_out_dir=${16}
force_recompute=${17}

force_flag=""
if [ "${force_recompute}" = "true" ]; then
    force_flag="--force-recompute"
fi

cmd="python ${src_dir}/compute_window_functions.py \
    --tavg-pspec-file ${tavg_pspec_file} \
    --algo ${algo} \
    --dataset-label ${dataset_label} \
    --bands ${bands} \
    --polpairs ${polpairs} \
    --taper ${taper} \
    --beam-file ${beam_file} \
    --ft-beam-pol ${ft_beam_pol} \
    --ft-beam-freq-min-hz ${ft_beam_freq_min_hz} \
    --ft-beam-freq-max-hz ${ft_beam_freq_max_hz} \
    --ft-beam-nfreq ${ft_beam_nfreq} \
    --ft-beam-mapsize ${ft_beam_mapsize} \
    --ft-beam-npix ${ft_beam_npix} \
    --ft-beam-cache-dirs ${ft_beam_cache_dirs} \
    --wf-dirs ${wf_dirs} \
    --wf-out-dir ${wf_out_dir} \
    ${force_flag}"

echo $cmd
eval $cmd

echo "Finished compute_window_functions.py for algo=${algo}, dataset=${dataset_label}, polpairs=${polpairs}, bands=${bands} at $(date)"
