"""
compute_ft_beam.py
==================

This script was commented (documented), edited, and cleaned with the help of Claude Opus 4.8.

Pipeline task: ensure a flat-sky FT-of-beam HDF5 file exists for the requested
(beam_file, polarization, frequency grid, mapsize, npix), producing one if
necessary. Output schema is compatible with `hera_pspec.uvwindow.FTBeam.from_file`.

Behavior
--------
The output filename encodes the differentiating parameters:
    FT_beam_HERA_Vivaldi_<pol>__<flo>-<fhi>MHz_<nfreq>ch_ms<mapsize>_N<npix>.hdf5
A file is reused if a filename matching the requested parameters is found in
any of the search directories. No metadata-matching, no hashing -- the user
is in the loop and `--force-recompute` is the escape hatch if anything
upstream changed without the filename reflecting it.

If no matching file is found, fall back to local computation. The local path
mirrors Adelie's `FT_beam_routine_Vivaldi.ipynb` (Part A): read UVBeam,
polarization-select, peak-normalize per frequency, project onto a Cartesian
sky plane, 2D-FFT each frequency slice. The two helpers
`convert_beam_to_cartesian` and `get_FT_beam` are inlined here (rather than
imported from a separate `helper_functions.py`) to keep the task_scripts
directory uncluttered.

The local path is fenced inside a `try / except NotImplementedError` so that
the day `hera_pspec.uvwindow.FTBeam.from_beam` lands upstream, the local code
becomes dead and can be removed by deleting the `except` branch.

CLI
---
    python compute_ft_beam.py \
        --beam-file /path/to/NF_HERA_Vivaldi_efield_beam.fits \
        --pol pI \
        --freq-min-hz 50.0e6 --freq-max-hz 250.0e6 --nfreq 2048 \
        --mapsize 1.0 --npix 299 \
        --cache-dirs "/lustre/.../FTBeam_cache:/lustre/.../agorce/FTBeams_Vivaldi" \
        --cache-out /lustre/.../FTBeam_cache \
        [--force-recompute]

`--cache-dirs` is a colon-separated path list (PATH-style). Search order is
left-to-right; writes always go to `--cache-out`.

Stdout summary on success:
    FT_BEAM_PATH=<absolute path to the file the next task should consume>
"""

import argparse
import datetime
import os
import sys
from pathlib import Path

import h5py
import numpy as np


# -----------------------------------------------------------------------------
# Inlined helpers from Adélie Gorce's helper_functions.py
# -----------------------------------------------------------------------------

# Cartesian half-width for the flat-sky beam projection. Lifted from
# helper_functions.py:18 (`max_r = 0.7  # 1/sqrt(2)`). The Cartesian grid
# spans `rx in [-max_r, +max_r]`; in `_cartesian_to_spherical`, zenith angle
# is za = sqrt(x^2 + y^2) in radians, so the corner of the grid sits at
# za = sqrt(2)*max_r = 1 rad (~57 deg) -- a sensible outer bound for the
# beam-relevant sky.
_DEFAULT_MAX_R = 0.7


def _cartesian_to_spherical(x, y):
    """Inverse of the simple zenith-angle x = za*cos(az), y = za*sin(az) map."""
    za = np.sqrt(x ** 2 + y ** 2)
    rho = np.divide(x, za, where=za != 0)
    az = np.arccos(rho)
    return az, za


def convert_beam_to_cartesian(data, az_range, za_range, N=500):
    """Project a (az, za) beam slice onto a Cartesian sky plane of size NxN.

    Returns
    -------
    rx : (N,) ndarray
        Cartesian coordinate axis. Half-width is `_DEFAULT_MAX_R`.
    b : (N, N) ndarray
        Beam interpolated onto the Cartesian grid, peak-normalized.
    """
    from scipy.ndimage import map_coordinates

    data = np.divide(data, data.max(), where=data.max() != 0)
    rx = np.linspace(-_DEFAULT_MAX_R, _DEFAULT_MAX_R, N)
    az, za = _cartesian_to_spherical(np.meshgrid(rx, rx)[0], np.meshgrid(rx, rx)[1])
    az_coords = az / np.diff(az_range).mean()
    za_coords = za / np.diff(za_range).mean()

    b = map_coordinates(data, [za_coords, az_coords], mode="nearest")
    b = np.divide(b, b.max(), where=b.max() != 0)
    if np.all(b.imag == 0.0):
        b = b.real
    return rx, b


def get_FT_beam(rx, b, N=500, mapsize=_DEFAULT_MAX_R):
    """Pad/crop the Cartesian beam to a centered grid and take the 2D FFT.

    `mapsize` controls the FT grid extent. Increasing it improves k-resolution
    at the cost of going beyond the simulation's spatial support.
    """
    dr = np.diff(rx).mean()
    ngrid = int(2.0 * mapsize / dr)
    if ngrid % 2 == 0:
        ngrid += 1  # odd, so the FT is centered on zero

    new_map = np.zeros((ngrid, ngrid), dtype=complex)
    if ngrid < N:
        new_map = b[(N - ngrid) // 2: -(N - ngrid) // 2,
                    (N - ngrid) // 2: -(N - ngrid) // 2]
    elif ngrid > N:
        new_map[-(N - ngrid) // 2: (N - ngrid) // 2,
                -(N - ngrid) // 2: (N - ngrid) // 2] = b
    else:
        new_map = np.copy(b)
        ngrid = rx.size

    Atilde = np.fft.fftshift(
        np.fft.fft2(np.fft.fftshift(new_map), norm="ortho")
        * (2.0 * mapsize / ngrid) ** 1.0
    )
    Atilde = np.flip(Atilde).real  # decreasing-order axes
    return Atilde


# -----------------------------------------------------------------------------
# Reuse lookup (filename-based)
# -----------------------------------------------------------------------------

def ft_beam_filename(pol, freq_array, mapsize, npix):
    """Standard filename encoding the differentiating params.

    Two FT-beam files with the same (pol, freq grid endpoints, nfreq, mapsize,
    npix) get the same filename and are considered interchangeable.

    The polarization MUST be the last underscore-separated token before
    ".hdf5". `hera_pspec.uvwindow.FTBeam.from_file` extracts pol via
    `str(ftfile).split('_')[-1].split('.')[0]` and asserts it against the
    valid-pol whitelist; putting pol anywhere else in the filename breaks
    that lookup.
    """
    nfreq = freq_array.size
    fmin = freq_array[0] / 1e6
    fmax = freq_array[-1] / 1e6
    return (
        f"FT_beam_HERA_Vivaldi__{fmin:.1f}-{fmax:.1f}MHz_"
        f"{nfreq}ch_ms{mapsize:g}_N{npix}_{pol}.hdf5"
    )


def find_ft_beam_in_cache(cache_dirs, pol, freq_array, mapsize, npix):
    """Search `cache_dirs` (in order) for a previously-computed FT beam.

    Returns the first matching path, or None. Match is filename-based: the
    differentiating parameters are baked into the filename by
    `ft_beam_filename`, so the lookup is a simple existence check.
    """
    target = ft_beam_filename(pol, freq_array, mapsize, npix)
    for cdir in cache_dirs:
        cand = Path(cdir) / target
        if cand.is_file():
            return cand
    return None


# -----------------------------------------------------------------------------
# Local computation (inlined Adélie's notebook Part A)
# -----------------------------------------------------------------------------

def _compute_ft_beam_locally(beam_file, freq_array, pol, mapsize, npix, verbose=True):
    """Compute the FT of the beam from a UVBeam simulation file.

    Mirrors `FT_beam_routine_Vivaldi.ipynb` cells 16-34. Returns:
        Atilde : (nfreq, ngrid, ngrid) ndarray, real
        ngrid  : int
        rx     : (npix,) Cartesian coordinate axis
    """
    from pyuvdata import UVBeam, utils as uvutils

    if verbose:
        print(f"[compute_ft_beam] Reading UVBeam from {beam_file}")
    beam = UVBeam()
    beam.read_beamfits(str(beam_file))

    polnum = uvutils.polstr2num(pol)
    if polnum < 0:
        beam.efield_to_power()
    else:
        beam.efield_to_pstokes()
    beam.select(polarizations=[polnum], inplace=True)
    beam.peak_normalize()

    az_range = beam.axis1_array
    za_range = beam.axis2_array

    if verbose:
        print(f"[compute_ft_beam] Interpolating beam to {freq_array.size} frequency channels"
              f" ({freq_array[0] / 1e6:.1f}-{freq_array[-1] / 1e6:.1f} MHz)")
    beam_res = beam._interp_freq(freq_array)[0][0, 0, ...]
    # peak-normalize per frequency
    beam_res /= np.max(beam_res, axis=(1, 2))[:, None, None]

    # ensure odd number of pixels so the FT is centered on zero
    if npix % 2 == 0:
        npix -= 1
        if verbose:
            print(f"[compute_ft_beam] Adjusted npix to odd: {npix}")

    nfreq = freq_array.size
    if verbose:
        print(f"[compute_ft_beam] Projecting beam to {npix}x{npix} Cartesian grid (per freq)")
    cart_beam = np.zeros((nfreq, npix, npix), dtype=complex)
    for ifreq in range(nfreq):
        rx, cart_beam[ifreq, :, :] = convert_beam_to_cartesian(
            beam_res[ifreq, :, :].real, az_range, za_range, N=npix
        )
        if verbose and (ifreq + 1) % max(1, nfreq // 20) == 0:
            sys.stdout.write(
                f"\r[compute_ft_beam]   Cartesian projection: {(ifreq + 1) / nfreq * 100:.0f}%"
            )
            sys.stdout.flush()
    if verbose:
        sys.stdout.write("\r[compute_ft_beam]   Cartesian projection: 100%\n")

    # ngrid is determined by mapsize + the rx spacing
    dr = np.diff(rx).mean()
    ngrid = int(2.0 * mapsize / dr)
    if ngrid % 2 == 0:
        ngrid += 1

    if verbose:
        print(f"[compute_ft_beam] Taking 2D FFT per frequency (ngrid={ngrid})")
    Atilde = np.zeros((nfreq, ngrid, ngrid))
    for ifreq in range(nfreq):
        Atilde[ifreq, :, :] = get_FT_beam(rx, cart_beam[ifreq, :, :],
                                          N=npix, mapsize=mapsize).real
        if verbose and (ifreq + 1) % max(1, nfreq // 20) == 0:
            sys.stdout.write(
                f"\r[compute_ft_beam]   2D FFT: {(ifreq + 1) / nfreq * 100:.0f}%"
            )
            sys.stdout.flush()
    if verbose:
        sys.stdout.write("\r[compute_ft_beam]   2D FFT: 100%\n")

    return Atilde, ngrid, rx


# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------

def _write_ft_beam_hdf5(out_path, Atilde, freq_array, mapsize, ngrid, npix, rx,
                        beam_file, pol):
    """Write Atilde + metadata in the schema FTBeam.from_file expects."""
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with h5py.File(out_path, "w") as f:
        # Required by hera_pspec.uvwindow.FTBeam.from_file:
        f.create_dataset("FT_beam", data=Atilde, compression="gzip")
        f.create_dataset("freq", data=freq_array)
        f.create_dataset("mapsize", data=np.array([mapsize]))
        # Extra fields (Adelie's convention; aid cache hits):
        f.create_dataset("ngrid", data=np.array([ngrid], dtype=int))
        f.create_dataset("npix_cart", data=np.array([npix], dtype=int))
        f.create_dataset("rx", data=rx)
        # Provenance:
        f.attrs["beam_file"] = str(beam_file)
        f.attrs["pol"] = str(pol)
        f.attrs["created_utc"] = datetime.datetime.utcnow().isoformat() + "Z"
        f.attrs["producer"] = "compute_ft_beam.py"


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def _ensure_ft_beam(beam_file, pol, freq_array, mapsize, npix,
                    cache_dirs, cache_out, force_recompute, verbose=True):
    """Top-level: filename-based reuse lookup, optional compute, write."""
    if not force_recompute:
        hit = find_ft_beam_in_cache(cache_dirs, pol, freq_array, mapsize, npix)
        if hit is not None:
            if verbose:
                print(f"[compute_ft_beam] Reusing existing FT beam: {hit}")
            return hit
        if verbose:
            print(f"[compute_ft_beam] No existing FT beam found in {cache_dirs}; "
                  "computing")
    else:
        if verbose:
            print("[compute_ft_beam] --force-recompute: skipping reuse lookup")

    # First, try the API path. Will become the only path once from_beam lands.
    try:
        from hera_pspec.uvwindow import FTBeam  # noqa: F401
        ftbeam = FTBeam.from_beam(  # type: ignore[call-arg]
            beamfile=str(beam_file),
            verbose=verbose,
        )
        # If we ever get here, FTBeam.from_beam has been implemented; we still
        # need to plumb our freq_array / mapsize / npix through. Until that
        # contract is fixed upstream, we conservatively raise so the local
        # path runs.
        raise NotImplementedError(
            "FTBeam.from_beam returned; rewire compute_ft_beam.py to use it."
        )
    except NotImplementedError:
        if verbose:
            print("[compute_ft_beam] FTBeam.from_beam unimplemented; "
                  "falling back to local computation.")
        Atilde, ngrid, rx = _compute_ft_beam_locally(
            beam_file, freq_array, pol, mapsize, npix, verbose=verbose
        )

    out_path = Path(cache_out) / ft_beam_filename(pol, freq_array, mapsize, npix)
    _write_ft_beam_hdf5(out_path, Atilde, freq_array, mapsize, ngrid, npix, rx,
                        beam_file, pol)
    if verbose:
        print(f"[compute_ft_beam] Wrote {out_path}")
    return out_path


def _build_freq_array(freq_min_hz, freq_max_hz, nfreq):
    """Endpoint convention matches Adelie's notebook: linspace, endpoint=False."""
    return np.linspace(freq_min_hz, freq_max_hz, nfreq, endpoint=False)


def _parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--beam-file", required=True,
                   help="Path to the UVBeam .fits / .beamfits simulation file.")
    p.add_argument("--pol", required=True,
                   help="Polarization string, e.g. 'pI', 'xx', 'yy'.")
    p.add_argument("--freq-min-hz", required=True, type=float,
                   help="Lower edge of the FT-beam freq grid, Hz.")
    p.add_argument("--freq-max-hz", required=True, type=float,
                   help="Upper edge of the FT-beam freq grid, Hz (exclusive, "
                        "linspace endpoint=False).")
    p.add_argument("--nfreq", required=True, type=int,
                   help="Number of frequency channels in the FT-beam grid.")
    p.add_argument("--mapsize", required=True, type=float,
                   help="Cartesian flat-sky map half-width (deg-ish; see Memo #128).")
    p.add_argument("--npix", required=True, type=int,
                   help="Number of pixels per side in the Cartesian projection (odd).")
    p.add_argument("--cache-dirs", required=True,
                   help="Colon-separated cache search list (PATH-style). "
                        "First match wins; writes go to --cache-out.")
    p.add_argument("--cache-out", required=True,
                   help="Directory where freshly computed FT-beam HDF5 files "
                        "are written. Must be writable.")
    p.add_argument("--force-recompute", action="store_true",
                   help="Skip cache lookup and recompute even if a hit exists.")
    p.add_argument("--quiet", action="store_true", help="Suppress progress chatter.")
    return p.parse_args()


def main():
    args = _parse_args()
    cache_dirs = [p for p in args.cache_dirs.split(":") if p]
    freq_array = _build_freq_array(args.freq_min_hz, args.freq_max_hz, args.nfreq)

    out = _ensure_ft_beam(
        beam_file=args.beam_file,
        pol=args.pol,
        freq_array=freq_array,
        mapsize=args.mapsize,
        npix=args.npix,
        cache_dirs=cache_dirs,
        cache_out=args.cache_out,
        force_recompute=args.force_recompute,
        verbose=not args.quiet,
    )
    # Print a structured line so downstream task scripts can capture the path
    # via e.g. `FT_BEAM_PATH=$(... | grep '^FT_BEAM_PATH=' | cut -d= -f2)`
    print(f"FT_BEAM_PATH={os.path.abspath(out)}")


if __name__ == "__main__":
    main()
