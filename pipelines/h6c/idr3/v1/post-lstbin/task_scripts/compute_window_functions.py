"""
compute_window_functions.py
===========================

This script was commented (documented), edited, and cleaned with the help of Claude Opus 4.8.

Pipeline task: ensure exact (or with-inpainting) window functions exist on
disk for each (algo, polpair, spw) tuple requested. Reads the merged
time-averaged pspec file, looks up the matching FT-beam HDF5 from the
FT-beam cache, then either reuses an existing WF HDF5 or computes one via
`UVPSpec.get_exact_window_functions` and writes it out. WFs are first-class
analysis products, not cache artifacts -- the "reuse if found" behavior just
avoids redundant recomputation across pipeline runs on the same dataset.

Reuse policy
------------
WF filenames encode the differentiating information directly:
    wf_<algo>_<polpair>_<dataset_label>_spw<NN>.hdf5
Reuse is a pure filename-existence check. `dataset_label` is a free-form
string the user sets in the TOML to disambiguate runs whose baseline content
differs (e.g. "086-nights_redavg-1000ns"). All of the inputs that produced
the WF are saved as HDF5 attrs for provenance / `h5dump` inspection, but
they don't gate reuse -- if upstream parameters change without a new
`dataset_label`, run with `--force-recompute`.

Algos
-----
- "exact"          : `UVPSpec.get_exact_window_functions(ftbeam=...)`. Implemented.
- "with-inpainting": placeholder; raises NotImplementedError until the
                     production implementation lands. (Old-style is retired.)

CLI
---
    python compute_window_functions.py \
        --tavg-pspec-file /path/to/baselines_merged.sum.tavg.pspec.h5 \
        --algo exact \
        --dataset-label 086-nights_redavg-1000ns \
        --bands 1,2,3,4,5,6,7,8,9,10,11,12,13,14 \
        --polpairs pI \
        --taper bh \
        --beam-file /path/to/NF_HERA_Vivaldi_efield_beam.fits \
        --ft-beam-pol pI \
        --ft-beam-freq-min-hz 50.0e6 --ft-beam-freq-max-hz 250.0e6 \
        --ft-beam-nfreq 2048 \
        --ft-beam-mapsize 1.0 --ft-beam-npix 299 \
        --ft-beam-cache-dirs "/lustre/.../FTBeam_cache" \
        --wf-dirs "/lustre/.../window_functions" \
        --wf-out-dir /lustre/.../window_functions \
        [--force-recompute]

Stdout summary on success: one `WF_PATH=<absolute path>` line per
(algo, polpair, spw) tuple processed.
"""

import argparse
import datetime
import os
import sys
from pathlib import Path

import h5py
import numpy as np

# Co-located task script. We share the FT-beam reuse lookup so both tasks
# agree on what counts as a match. `__file__`'s parent is task_scripts/,
# which already contains compute_ft_beam.py.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from compute_ft_beam import find_ft_beam_in_cache  # noqa: E402


# -----------------------------------------------------------------------------
# Filename + reuse lookup
# -----------------------------------------------------------------------------

def wf_filename(algo, polpair, dataset_label, spw_index):
    """Standard filename. Differentiating info baked into the filename."""
    return f"wf_{algo}_{polpair}_{dataset_label}_spw{spw_index:02d}.hdf5"


def find_wf_on_disk(wf_dirs, algo, polpair, dataset_label, spw_index):
    """Search `wf_dirs` (in order) for a previously-computed WF.

    Returns the first matching path, or None. Match is filename-based.
    """
    target = wf_filename(algo, polpair, dataset_label, spw_index)
    for wdir in wf_dirs:
        cand = Path(wdir) / target
        if cand.is_file():
            return cand
    return None


# -----------------------------------------------------------------------------
# Computation
# -----------------------------------------------------------------------------

def _compute_wf_exact(uvp_one_spw, ftbeam):
    """Run UVPSpec.get_exact_window_functions and return (kperp, kpara, wf)."""
    kperp_bins, kpara_bins, wf = uvp_one_spw.get_exact_window_functions(
        ftbeam=ftbeam, verbose=True, inplace=False,
    )
    # When a single spw is selected, each return is a length-1 list/dict.
    return kperp_bins[0], kpara_bins[0], wf[0]


def _compute_wf_with_inpainting(uvp_one_spw, ftbeam):
    """Inpainting-aware WF. TODO: wire to production code when available."""
    raise NotImplementedError(
        "WINDOW_FUNCTION_ALGO='with-inpainting' is reserved but not yet "
        "implemented in this task script. Wire it here once the production "
        "code path is settled (Chen+2025 inpainting WFs)."
    )


# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------

def _write_wf_hdf5(out_path, wf, kperp, kpara, provenance, tavg_pspec_file,
                   ft_beam_path):
    """Write WF + kperp + kpara + provenance attrs.

    `provenance` is a dict of fields documenting how the WF was produced.
    These attrs are NOT used to gate reuse (filename does that); they exist
    for `h5dump` inspection and later debugging.
    """
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with h5py.File(out_path, "w") as f:
        f.create_dataset("wf", data=wf, compression="gzip")
        f.create_dataset("kperp", data=kperp)
        f.create_dataset("kpara", data=kpara)
        for k, v in provenance.items():
            f.attrs[k] = v
        f.attrs["tavg_pspec_file"] = str(tavg_pspec_file)
        f.attrs["ft_beam_path"] = str(ft_beam_path)
        f.attrs["created_utc"] = datetime.datetime.utcnow().isoformat() + "Z"
        f.attrs["producer"] = "compute_window_functions.py"


# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------

def _process_one(uvp, spw_index, polpair, algo, dataset_label, taper,
                 ftbeam, ft_beam_path, ft_beam_provenance, tavg_pspec_file,
                 wf_dirs, wf_out_dir, force_recompute, verbose):
    """Reuse-or-compute one (algo, polpair, spw_index) tuple."""
    if not force_recompute:
        hit = find_wf_on_disk(wf_dirs, algo, polpair, dataset_label, spw_index)
        if hit is not None:
            if verbose:
                print(f"[compute_window_functions] Reusing existing WF "
                      f"(spw={spw_index}, pol={polpair}, algo={algo}): {hit}")
            print(f"WF_PATH={os.path.abspath(hit)}")
            return hit
        if verbose:
            print(f"[compute_window_functions] No existing WF for "
                  f"(spw={spw_index}, pol={polpair}, algo={algo}); computing")

    # Down-select to one (spw, polpair) and compute
    sub = uvp.select(polpairs=[polpair], spws=[spw_index], inplace=False)
    if algo == "exact":
        kperp, kpara, wf = _compute_wf_exact(sub, ftbeam)
    elif algo == "with-inpainting":
        kperp, kpara, wf = _compute_wf_with_inpainting(sub, ftbeam)
    else:
        raise ValueError(f"Unknown algo: {algo!r}. "
                         "Expected 'exact' or 'with-inpainting'.")

    spw_freqs = uvp.freq_array[uvp.spw_freq_array == spw_index]
    provenance = {
        "algo": algo,
        "polpair": polpair,
        "spw_index": int(spw_index),
        "dataset_label": dataset_label,
        "taper": taper,
        "spw_freq_min_hz": float(spw_freqs.min()),
        "spw_freq_max_hz": float(spw_freqs.max()),
        **ft_beam_provenance,
    }
    out_path = Path(wf_out_dir) / wf_filename(algo, polpair, dataset_label,
                                              spw_index)
    _write_wf_hdf5(out_path, wf, kperp, kpara, provenance,
                   tavg_pspec_file, ft_beam_path)
    if verbose:
        print(f"[compute_window_functions] Wrote {out_path}")
    print(f"WF_PATH={os.path.abspath(out_path)}")
    return out_path


def _build_freq_array(freq_min_hz, freq_max_hz, nfreq):
    """Same convention as compute_ft_beam.py: linspace, endpoint=False."""
    return np.linspace(freq_min_hz, freq_max_hz, nfreq, endpoint=False)


def _resolve_ft_beam_path(args, verbose):
    """Locate the FT-beam HDF5 the WF computation will use.

    Uses the same filename-based reuse lookup as compute_ft_beam.py, so the
    two tasks agree on filename conventions. If nothing matches, error --
    COMPUTE_FT_BEAM should have run first as a prereq.
    """
    cache_dirs = [p for p in args.ft_beam_cache_dirs.split(":") if p]
    freq_array = _build_freq_array(args.ft_beam_freq_min_hz,
                                   args.ft_beam_freq_max_hz,
                                   args.ft_beam_nfreq)
    hit = find_ft_beam_in_cache(
        cache_dirs, args.ft_beam_pol, freq_array,
        args.ft_beam_mapsize, args.ft_beam_npix,
    )
    if hit is None:
        raise FileNotFoundError(
            f"No FT-beam HDF5 in cache dirs {cache_dirs} for "
            f"pol={args.ft_beam_pol}, freq=[{args.ft_beam_freq_min_hz/1e6:.1f}-"
            f"{args.ft_beam_freq_max_hz/1e6:.1f} MHz]/{args.ft_beam_nfreq}ch, "
            f"mapsize={args.ft_beam_mapsize}, npix={args.ft_beam_npix}. "
            "Run COMPUTE_FT_BEAM first."
        )
    if verbose:
        print(f"[compute_window_functions] Using FT beam: {hit}")
    return hit


def _parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    # Inputs
    p.add_argument("--tavg-pspec-file", required=True,
                   help="Path to merged time-averaged pspec h5 file.")
    p.add_argument("--algo", required=True, choices=("exact", "with-inpainting"),
                   help="Window function algorithm.")
    p.add_argument("--dataset-label", required=True,
                   help="Free-form string disambiguating runs whose baseline "
                        "content differs (e.g. '086-nights_redavg-1000ns'). "
                        "Becomes part of the WF filename, so different "
                        "labels never collide on disk.")
    p.add_argument("--bands", required=True,
                   help="Comma-separated 1-indexed band numbers, e.g. '1,2,3,...,14'.")
    p.add_argument("--polpairs", required=True,
                   help="Comma-separated polpair strings, e.g. 'pI' or 'pI,pQ'.")
    p.add_argument("--taper", required=True,
                   help="Taper string used in pspec (e.g. 'bh' / 'blackman-harris'); "
                        "used as a cache-key field only -- the actual taper was "
                        "applied during pspec computation.")

    # FT-beam discovery (must match what COMPUTE_FT_BEAM was run with)
    p.add_argument("--beam-file", required=True,
                   help="Path to UVBeam .fits sim. Used as a cache-key field.")
    p.add_argument("--ft-beam-pol", required=True)
    p.add_argument("--ft-beam-freq-min-hz", required=True, type=float)
    p.add_argument("--ft-beam-freq-max-hz", required=True, type=float)
    p.add_argument("--ft-beam-nfreq", required=True, type=int)
    p.add_argument("--ft-beam-mapsize", required=True, type=float)
    p.add_argument("--ft-beam-npix", required=True, type=int)
    p.add_argument("--ft-beam-cache-dirs", required=True,
                   help="Colon-separated cache search list (PATH-style) for FT beam.")

    # WF products
    p.add_argument("--wf-dirs", required=True,
                   help="Colon-separated search list (PATH-style) of "
                        "directories holding WF HDF5 products. Existing files "
                        "with matching attrs are reused.")
    p.add_argument("--wf-out-dir", required=True,
                   help="Directory to write fresh WF HDF5s.")
    p.add_argument("--force-recompute", action="store_true",
                   help="Skip the reuse lookup and recompute even if a "
                        "matching WF already exists on disk.")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args()


def main():
    args = _parse_args()
    verbose = not args.quiet

    # Late import: hera_pspec is heavy.
    import hera_pspec as hp
    from hera_pspec.uvwindow import FTBeam

    # Resolve and load the FT beam
    ft_beam_path = _resolve_ft_beam_path(args, verbose)
    ftbeam = FTBeam.from_file(str(ft_beam_path))

    # FT-beam params ride along on each WF as provenance attrs (not a reuse
    # gate -- if these change without dataset_label changing, the user is
    # expected to use --force-recompute).
    ft_beam_provenance = {
        "ft_beam_pol": args.ft_beam_pol,
        "ft_beam_freq_min_hz": float(args.ft_beam_freq_min_hz),
        "ft_beam_freq_max_hz": float(args.ft_beam_freq_max_hz),
        "ft_beam_nfreq": int(args.ft_beam_nfreq),
        "ft_beam_mapsize": float(args.ft_beam_mapsize),
        "ft_beam_npix": int(args.ft_beam_npix),
        "beam_file": str(args.beam_file),
    }

    # Load UVPSpec
    if verbose:
        print(f"[compute_window_functions] Loading {args.tavg_pspec_file}")
    psc = hp.container.PSpecContainer(args.tavg_pspec_file, mode="r",
                                      keep_open=False)
    uvp = psc.get_pspec("stokespol", "time_and_interleave_averaged")

    # Bands are 1-indexed; spw indices are 0-indexed
    bands = [int(b) for b in args.bands.split(",") if b.strip()]
    polpairs = [p for p in args.polpairs.split(",") if p.strip()]
    wf_dirs = [p for p in args.wf_dirs.split(":") if p]

    Path(args.wf_out_dir).mkdir(parents=True, exist_ok=True)

    for band in bands:
        spw_index = band - 1
        for polpair in polpairs:
            _process_one(
                uvp=uvp, spw_index=spw_index, polpair=polpair,
                algo=args.algo, dataset_label=args.dataset_label,
                taper=args.taper,
                ftbeam=ftbeam, ft_beam_path=ft_beam_path,
                ft_beam_provenance=ft_beam_provenance,
                tavg_pspec_file=args.tavg_pspec_file,
                wf_dirs=wf_dirs,
                wf_out_dir=args.wf_out_dir,
                force_recompute=args.force_recompute,
                verbose=verbose,
            )


if __name__ == "__main__":
    main()
