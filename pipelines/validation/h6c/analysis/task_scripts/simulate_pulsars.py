#!/usr/bin/env python
"""Simulate polarized pulsars on the layout of an existing visibility file.

The output has the same baselines, times, frequencies, polarizations and
conjugation as a reference uvh5 file (an original validation-sim file, or a
night's data file), so it can be added directly to that file's visibilities.

Visibilities are computed by direct summation over the sources (see
:func:`direct_vis_chunks`), which costs ~Nsrc x Nbls x Ntimes x Nfreqs and is much
faster than an FFT-based simulator for a handful of sources. The coordinate
rotation, coherency rotation, beam interpolation and feed conventions are those of
fftvis/matvis, configured to match how the H6C validation sims were produced with
hera_sim + fftvis (https://github.com/HERA-Team/validation-sim,
``package-structure`` branch):

* coordinates: matvis ``CoordinateRotationERFA`` with
  ``update_bcrs_every=1e8`` (BCRS set once, at the first time);
* beam: an efield UVBeam (NF_HERA_Vivaldi_efield_beam_extrap.fits for the
  originals), peak-normalized; for each simulated channel the beam channels
  within +/- 3 MHz are selected and cubically interpolated to that channel,
  then interpolated spatially with ``az_za_map_coordinates`` at spline order 1;
* polarized simulation (all four feed products), double precision;
* imaginary parts of xx/yy autos removed (``hera-sim-vis.py --fix_autos``).

Each source has a power-law Stokes I spectrum and a constant fractional linear
polarization, Faraday-rotated by its rotation measure:

    I(f)       = S_ref (f / f_ref)^alpha
    Q + iU     = p I(f) exp(2i [chi_0 + RM (c/f)^2])
    V          = v I(f)

An optional per-source gain (per time, or per time and frequency) multiplies
all four Stokes parameters, e.g. to inject scintillation.

Requires matvis (for its coordinate and coherency rotations), pyuvdata, astropy
and pyyaml.

Example
-------
From the command line::

    python simulate_pulsars.py ref.uvh5 NF_HERA_Vivaldi_efield_beam_extrap.fits pulsars.uvh5

From Python, reusing one resampled beam for many reference files that share a
frequency axis::

    from pyuvdata import UVBeam, UVData
    import simulate_pulsars as sp

    beam = UVBeam.from_file("NF_HERA_Vivaldi_efield_beam_extrap.fits")
    ref = UVData.from_file(first_file, read_data=False)
    sim_beam = sp.resample_beam(beam, ref.freq_array)
    for fname in files:
        ref = UVData.from_file(fname, read_data=False)
        uvd = sp.simulate_pulsars(ref, sim_beam, beam_is_resampled=True)
"""

from __future__ import annotations

import argparse
import copy
from collections.abc import Iterator, Mapping, Sequence
from pathlib import Path

import numpy as np
import yaml
from astropy import units as un
from astropy.coordinates import EarthLocation, SkyCoord
from astropy.time import Time
from matvis.coordinates import calc_coherency_rotation, enu_to_az_za
from matvis.core.coords import CoordinateRotation
from pyuvdata import UVBeam, UVData
from pyuvdata import utils as uvutils

SPEED_OF_LIGHT = 299792458.0  # m/s

# Simulation settings of the original validation sims (validation-sim
# simulator-specs/fftvis*-cpu.yaml, obsparams.py and runscripts/main/*.sh).
COORD_METHOD = "CoordinateRotationERFA"
COORD_METHOD_PARAMS = {"update_bcrs_every": 1e8}
INTERPOLATION_FUNCTION = "az_za_map_coordinates"
BEAM_SPLINE_OPTS = {"order": 1}
FREQ_INTERP_KIND = "cubic"
FREQ_BUFFER = 3.0e6  # Hz, beam channels kept on either side of each simulated channel
CHUNK_BYTES = 256 * 1024**2  # default size of the visibilities computed per block of times

# Pulsar parameters.
#
# Positions, Stokes I, spectral index, linear polarization fraction and the
# low-frequency RMs are from the POGS-II pulsar catalogue (Riseley et al. 2020,
# PASA 37, e029; MWA 169-231 MHz, reference frequency 200 MHz). The RMs used
# below are the ATNF catalogue values quoted in POGS-II (``rm_ref``); the
# ionosphere-corrected POGS-II RMs are given alongside. The intrinsic
# polarization angle chi_0 is not catalogued and is set to zero.
PULSARS = {
    "J0630-2834": {
        "ra_deg": 97.70711,
        "dec_deg": -28.57466,
        "ref_freq_hz": 200e6,
        "stokes_i_jy": 0.463,  # POGS-II, +/- 0.005
        "spectral_index": -1.2,  # POGS-II, +/- 0.1
        "pol_fraction": 0.46,  # POGS-II, +/- 0.01 (polarized intensity 0.211 Jy)
        "rm": 46.53,  # rad/m^2, ATNF (+/- 0.12); POGS-II: 46.65 +/- 0.02
        "pol_angle_deg": 0.0,
        "circ_fraction": 0.0,
    },
    "J0742-2822": {
        "ra_deg": 115.70607,
        "dec_deg": -28.37458,
        "ref_freq_hz": 200e6,
        # POGS-II measures only the polarized intensity, 0.263 +/- 0.004 Jy;
        # it has no Stokes I or spectral index for this pulsar. Stokes I and
        # the spectral index below are ASSUMPTIONS (polarization fraction to match polarized intensity
        # J0630-2834's spectral index)
        "stokes_i_jy": 0.387,
        "spectral_index": -1.2,
        "pol_fraction": 0.68,
        "rm": 149.95,  # rad/m^2, ATNF (+/- 0.05); POGS-II: 150.74 +/- 0.02
        "pol_angle_deg": 0.0,
        "circ_fraction": 0.0,
    },
}


def stokes_spectra(source: Mapping, freqs: np.ndarray) -> np.ndarray:
    """Return Stokes [I, Q, U, V] of one source in Jy, shape (Nfreqs, 4).

    Parameters
    ----------
    source : mapping
        Source parameters, with the keys used in :data:`PULSARS`.
        ``pol_angle_deg`` and ``circ_fraction`` default to zero.
    freqs : np.ndarray
        Frequencies in Hz.
    """
    freqs = np.asarray(freqs, dtype=float)
    stokes_i = source["stokes_i_jy"] * (freqs / source["ref_freq_hz"]) ** source["spectral_index"]
    chi = np.deg2rad(source.get("pol_angle_deg", 0.0)) + source["rm"] * (SPEED_OF_LIGHT / freqs) ** 2
    pol = source["pol_fraction"] * stokes_i
    return np.stack(
        [
            stokes_i,
            pol * np.cos(2 * chi),
            pol * np.sin(2 * chi),
            source.get("circ_fraction", 0.0) * stokes_i,
        ],
        axis=-1,
    )


def resample_beam(
    beam: UVBeam,
    freqs: np.ndarray,
    freq_buffer: float = FREQ_BUFFER,
    freq_interp_kind: str = FREQ_INTERP_KIND,
    za_max: float | None = np.pi / 2,
) -> UVBeam:
    """Peak-normalize an efield UVBeam and interpolate it onto ``freqs``.

    Each output channel is interpolated only from the beam channels within
    ``freq_buffer`` of it, which reproduces how the validation sims built
    their beams (one channel per run, beam read with ``freq_buffer``).

    Parameters
    ----------
    beam : UVBeam
        Efield beam with an az/za pixel grid. Not modified.
    freqs : np.ndarray
        Output frequencies in Hz.
    freq_buffer : float
        Half-width in Hz of the window of beam channels used for each output channel.
    freq_interp_kind : str
        Frequency interpolation kind passed to :meth:`UVBeam.interp`.
    za_max : float or None
        Zenith-angle rows beyond this (radians), plus two grid rows of margin,
        are dropped to save memory. Sources below the horizon are never
        evaluated, so this does not change the result. None keeps every row.

    Returns
    -------
    UVBeam
        Peak-normalized efield beam with ``freq_array`` equal to ``freqs``.

    Raises
    ------
    ValueError
        If the beam is not an az/za efield beam, or if fewer beam channels than
        the interpolation needs fall within ``freq_buffer`` of an output channel.
    """
    if beam.beam_type != "efield" or beam.pixel_coordinate_system != "az_za":
        raise ValueError("beam must be an az_za efield UVBeam")
    freqs = np.atleast_1d(np.asarray(freqs, dtype=float)).ravel()

    beam = beam.copy()
    if za_max is not None and beam.axis2_array.max() > za_max:
        dza = np.median(np.diff(beam.axis2_array))
        keep = np.nonzero(beam.axis2_array <= za_max + 2 * dza)[0]
        beam.select(axis2_inds=keep, run_check=False)
    beam.peak_normalize()

    out = beam.interp(freq_array=freqs, new_object=True, freq_interp_kind="nearest", run_check=False)
    min_chans = {"linear": 2, "quadratic": 3, "cubic": 4}.get(freq_interp_kind, 1)
    for i, freq in enumerate(freqs):
        chans = np.nonzero(
            (beam.freq_array >= freq - freq_buffer) & (beam.freq_array <= freq + freq_buffer)
        )[0]
        if chans.size == 0 or (
            chans.size < min_chans and np.min(np.abs(beam.freq_array[chans] - freq)) >= 1.0
        ):
            raise ValueError(
                f"only {chans.size} beam channels within {freq_buffer / 1e6} MHz of "
                f"{freq / 1e6:.4f} MHz; '{freq_interp_kind}' interpolation needs {min_chans}"
            )
        window = beam.select(freq_chans=chans, inplace=False, run_check=False)
        one = window.interp(
            freq_array=np.array([freq]), new_object=True, freq_interp_kind=freq_interp_kind, run_check=False
        )
        out.data_array[:, :, i] = one.data_array[:, :, 0]
        out.bandpass_array[i] = one.bandpass_array[0]
    out.history += (
        f"\nPeak-normalized and interpolated to {freqs.size} channels with "
        f"'{freq_interp_kind}' interpolation over +/- {freq_buffer / 1e6} MHz windows."
    )
    return out


def feed_products(uvd: UVData, beam: UVBeam) -> list[tuple[int, int]]:
    """Map each polarization of ``uvd`` to its (feed1, feed2) indices in ``beam.feed_array``.

    Follows ``hera_sim.visibilities.MatVis._get_req_pols``, which the original
    sims used to reorder fftvis output.
    """
    feeds = [str(f).lower() for f in beam.feed_array]
    x_orientation = None if set(feeds) <= {"x", "y"} else beam.get_x_orientation_from_feeds()
    avail = {f1 + f2: (feeds.index(f1), feeds.index(f2)) for f1 in feeds for f2 in feeds}
    pols = [uvutils.polnum2str(p, x_orientation=x_orientation) for p in uvd.polarization_array]
    missing = [p for p in pols if p not in avail]
    if missing:
        raise ValueError(f"polarizations {missing} cannot be formed from beam feeds {feeds}")
    return [avail[p] for p in pols]


def direct_vis_chunks(
    ants: Mapping[int, np.ndarray],
    stokes: np.ndarray,
    ra: np.ndarray,
    dec: np.ndarray,
    freqs: np.ndarray,
    times: np.ndarray,
    beam: UVBeam,
    telescope_loc: EarthLocation,
    baselines: Sequence[tuple[int, int]],
    gains: np.ndarray | None = None,
    times_per_chunk: int | None = None,
) -> Iterator[tuple[slice, np.ndarray]]:
    """Yield polarized visibilities of point sources, one block of times at a time.

    For baseline (i, j) and feed product (p, q),

        V_pq(f, t) = sum_s g_s(t, f) [A_s^H C_s(f, t) A_s]_qp exp(2 pi i f (x_j - x_i) . s(t) / c),

    where A_s is the beam Jones matrix towards source s and C_s its coherency in the
    local alt/az frame. The conventions are fftvis's (``fftvis.simulate_vis`` with
    ``polarized=True``): Stokes I is split equally between the two linear feeds, the
    coherency is rotated from RA/Dec to alt/az with matvis' ``calc_coherency_rotation``,
    and the Jones vector components are in the reverse of UVBeam's vector-axis order.
    Sources below the horizon contribute nothing.

    Parameters
    ----------
    ants : mapping
        ``{antenna number: ENU position}`` in meters.
    stokes : np.ndarray
        Stokes [I, Q, U, V] in Jy, shape (Nsrc, Nfreqs, 4).
    ra, dec : np.ndarray
        ICRS positions in radians, shape (Nsrc,).
    freqs : np.ndarray
        Frequencies in Hz.
    times : np.ndarray
        Julian dates.
    beam : UVBeam
        Efield beam used for every antenna, with a channel at every simulated
        frequency (e.g. from :func:`resample_beam`), so it is only interpolated spatially.
    telescope_loc : EarthLocation
        Array center.
    baselines : sequence of (ant1, ant2)
        Baselines to simulate, in the output order.
    gains : np.ndarray, optional
        Real factors of shape (Nsrc, Ntimes, Nfreqs) multiplying all Stokes parameters.
    times_per_chunk : int, optional
        Times per yielded block. Defaults to blocks of about ``CHUNK_BYTES``.

    Yields
    ------
    tslice : slice
        The times covered by the block.
    vis : np.ndarray
        Complex visibilities of shape (Nfreqs, Ntimes_in_block, 2, 2, Nbls). The buffer is
        reused, so copy or store each block before requesting the next.
    """
    freqs = np.asarray(freqs, dtype=float)
    times = Time(np.asarray(times), format="jd")
    nsrc, nt, nf, nbl = len(ra), len(times), len(freqs), len(baselines)

    beam_freqs = np.asarray(beam.freq_array).ravel()
    dist = np.abs(beam_freqs[None, :] - freqs[:, None])
    if np.any(dist.min(axis=1) >= 1.0):
        raise ValueError("beam must have a channel at every simulated frequency (see resample_beam)")
    beam_chan = dist.argmin(axis=1)

    # Source directions as ENU unit vectors, (3, Ntimes, Nsrc)
    rotation = CoordinateRotation._methods[COORD_METHOD](
        flux=np.ones((nsrc, 1)),
        times=times,
        telescope_loc=telescope_loc,
        skycoords=SkyCoord(ra=ra * un.rad, dec=dec * un.rad, frame="icrs"),
        precision=2,
        **COORD_METHOD_PARAMS,
    )
    rotation.setup()
    topo = np.empty((3, nt, nsrc))
    for ti in range(nt):
        rotation.rotate(ti)
        topo[:, ti] = rotation.all_coords_topo
    up = topo[2] > 0
    az_beam, za = enu_to_az_za(enu_e=topo[0], enu_n=topo[1], orientation="uvbeam")
    az_sky, _ = enu_to_az_za(enu_e=topo[0], enu_n=topo[1], orientation="astropy")

    # Coherency in the RA/Dec frame, (Nsrc, Nfreqs, 2, 2)
    stokes_i, stokes_q, stokes_u, stokes_v = np.moveaxis(np.asarray(stokes, dtype=float), -1, 0)
    coherency = 0.5 * np.moveaxis(
        np.array([[stokes_i + stokes_q, stokes_u + 1j * stokes_v], [stokes_u - 1j * stokes_v, stokes_i - stokes_q]]),
        (0, 1),
        (-2, -1),
    )

    # Geometric delays (x_j - x_i) . s / c, (Ntimes, Nsrc, Nbls)
    blvec = np.array([np.asarray(ants[a2]) - np.asarray(ants[a1]) for a1, a2 in baselines])
    tau = np.einsum("bk,kts->tsb", blvec, topo) / SPEED_OF_LIGHT

    if times_per_chunk is None:
        times_per_chunk = max(1, int(CHUNK_BYTES // (nf * nbl * 4 * 16)))
    vis = None
    for t0 in range(0, nt, times_per_chunk):
        tsl = slice(t0, min(t0 + times_per_chunk, nt))
        ntc = tsl.stop - tsl.start
        if vis is None or vis.shape[1] != ntc:
            vis = np.empty((nf, ntc, 2, 2, nbl), dtype=complex)
        up_c = up[tsl]

        # Beam Jones along the source tracks, (2 vector axes, 2 feeds, Nfreqs, ntc, Nsrc)
        jones = np.zeros((2, 2, nf, ntc, nsrc), dtype=complex)
        if up_c.any():
            resp, _ = beam.interp(
                az_array=az_beam[tsl][up_c],
                za_array=za[tsl][up_c],
                freq_array=None,
                return_basis_vector=False,
                interpolation_function=INTERPOLATION_FUNCTION,
                spline_opts=BEAM_SPLINE_OPTS,
                reuse_spline=True,
                check_azza_domain=False,
            )
            jones[..., up_c] = resp[:, :, beam_chan]
        jones = np.flip(jones, axis=0)

        # Coherency rotated into each time's alt/az frame, (Nsrc, ntc, Nfreqs, 2, 2)
        coh = np.zeros((nsrc, ntc, nf, 2, 2), dtype=complex)
        for k, ti in enumerate(range(tsl.start, tsl.stop)):
            s = np.flatnonzero(up[ti])
            if s.size:
                rot = calc_coherency_rotation(
                    ra=ra[s], dec=dec[s], alt=np.pi / 2 - za[ti, s], az=az_sky[ti, s],
                    time=times[ti], location=telescope_loc,
                )
                coh[s, k] = np.einsum("ban,nfbc,cdn->nfad", rot, coherency[s], rot)
        if gains is not None:
            coh *= gains[:, tsl, :, None, None]

        # Apparent coherency; feed product (p, q) is element (q, p) of A^H C A. (Nfreqs, ntc, 4, Nsrc)
        app = np.einsum("apfts,stfac,cqfts->ftqps", jones.conj(), coh, jones, optimize=True)
        app = app.reshape(nf, ntc, 4, nsrc)

        # Sum over sources, a few channels at a time to bound memory
        fstep = max(1, int(64 * 1024**2 // (ntc * nsrc * nbl * 16)))
        for f0 in range(0, nf, fstep):
            fs = slice(f0, min(f0 + fstep, nf))
            phase = np.exp(2j * np.pi * freqs[fs, None, None, None] * tau[None, tsl])  # (nfs, ntc, Nsrc, Nbls)
            vis[fs] = np.matmul(app[fs], phase).reshape(-1, ntc, 2, 2, nbl)
        yield tsl, vis


def simulate_pulsars(
    ref: UVData,
    beam: UVBeam,
    sources: Mapping[str, Mapping] | None = None,
    gains: Mapping[str, np.ndarray] | None = None,
    beam_is_resampled: bool = False,
    freq_buffer: float = FREQ_BUFFER,
    times_per_chunk: int | None = None,
) -> UVData:
    """Simulate polarized point sources on the layout of ``ref``.

    Parameters
    ----------
    ref : UVData
        Reference data. Its antenna positions, telescope location, baselines
        (with their conjugation), times, frequencies and polarizations define
        the output; its visibilities are not used, so it may be read with
        ``read_data=False``.
    beam : UVBeam
        Efield beam used for every antenna. With ``beam_is_resampled=False`` it
        is passed through :func:`resample_beam` first.
    sources : mapping, optional
        ``{name: parameters}`` in the format of :data:`PULSARS`, which is the default.
    gains : mapping, optional
        ``{name: gain}`` multiplying all Stokes parameters of that source.
        Each gain is real with shape ``(Ntimes,)`` or ``(Ntimes, Nfreqs)``,
        ordered like the unique times and the frequencies of ``ref``.
    beam_is_resampled : bool
        True if ``beam`` already came from :func:`resample_beam` for these frequencies.
    freq_buffer : float
        Passed to :func:`resample_beam`.
    times_per_chunk : int, optional
        Number of times simulated at once; passed to :func:`direct_vis_chunks`.

    Returns
    -------
    UVData
        Copy of the metadata of ``ref`` holding the simulated visibilities, with
        no flags and unit nsamples.

    Raises
    ------
    ValueError
        If ``ref`` is phased (not drift-scan), if a gain has the wrong shape or
        names an unknown source, or if the beam frequencies do not match ``ref``
        when ``beam_is_resampled`` is True.
    """
    if any(cat["cat_type"] != "unprojected" for cat in ref.phase_center_catalog.values()):
        raise ValueError("ref must be unprojected (drift-scan) data")
    sources = PULSARS if sources is None else sources
    gains = {} if gains is None else gains
    unknown = set(gains) - set(sources)
    if unknown:
        raise ValueError(f"gains given for unknown sources: {sorted(unknown)}")

    freqs = np.asarray(ref.freq_array, dtype=float).ravel()
    times = np.unique(ref.time_array)
    nfreqs, ntimes = freqs.size, times.size

    if beam_is_resampled:
        if beam.Nfreqs != nfreqs or np.max(np.abs(beam.freq_array - freqs)) >= 1.0:
            raise ValueError("resampled beam frequencies do not match the reference frequencies")
    else:
        beam = resample_beam(beam, freqs, freq_buffer=freq_buffer)

    names = list(sources)
    ra = np.deg2rad([sources[n]["ra_deg"] for n in names])
    dec = np.deg2rad([sources[n]["dec_deg"] for n in names])
    stokes = np.array([stokes_spectra(sources[n], freqs) for n in names])  # (Nsrc, Nfreqs, 4)
    gain_array = None
    if gains:
        gain_array = np.ones((len(names), ntimes, nfreqs))
        for name, gain in gains.items():
            gain = np.asarray(gain, dtype=float)
            if gain.shape == (ntimes,):
                gain = gain[:, None]
            elif gain.shape != (ntimes, nfreqs):
                raise ValueError(
                    f"gain for {name} has shape {gain.shape}; expected ({ntimes},) or ({ntimes}, {nfreqs})"
                )
            gain_array[names.index(name)] *= gain

    antpos, antnums = ref.get_enu_data_ants()
    ants = dict(zip(antnums, antpos))
    antpairs = ref.get_antpairs()
    pol_feeds = feed_products(ref, beam)

    uvd = ref.copy(metadata_only=True)
    uvd.data_array = np.zeros((uvd.Nblts, uvd.Nfreqs, uvd.Npols), dtype=complex)
    uvd.flag_array = np.zeros(uvd.data_array.shape, dtype=bool)
    uvd.nsample_array = np.ones(uvd.data_array.shape, dtype=float)

    # (time index, baseline index) of every baseline-time
    blt_time = np.searchsorted(times, uvd.time_array)
    bl_nums = uvd.antnums_to_baseline(*np.array(antpairs).T)
    bl_order = np.argsort(bl_nums)
    blt_bl = bl_order[np.searchsorted(bl_nums[bl_order], uvd.baseline_array)]

    chunks = direct_vis_chunks(
        ants=ants,
        stokes=stokes,
        ra=ra,
        dec=dec,
        freqs=freqs,
        times=times,
        beam=beam,
        telescope_loc=ref.telescope.location,
        baselines=antpairs,
        gains=gain_array,
        times_per_chunk=times_per_chunk,
    )
    for tslice, vis in chunks:  # vis: (Nfreqs, Ntimes_chunk, 2, 2, Nbls)
        blts = np.nonzero((blt_time >= tslice.start) & (blt_time < tslice.stop))[0]
        t_local = blt_time[blts] - tslice.start
        for ipol, (f1, f2) in enumerate(pol_feeds):
            uvd.data_array[blts, :, ipol] = vis[:, t_local, f1, f2, blt_bl[blts]].T

    uvd._fix_autos()
    uvd.history += (
        "\nPolarized point sources simulated by direct summation (simulate_pulsars.py) "
        f"(coord_method={COORD_METHOD}, interpolation_function={INTERPOLATION_FUNCTION}, "
        f"spline_opts={BEAM_SPLINE_OPTS}). Sources: "
        + "; ".join(f"{n}: {dict(sources[n])}" for n in names)
        + (f". Time-variable gains applied to: {sorted(gains)}." if gains else ".")
    )
    return uvd


def _load_sources(path: str | None) -> dict:
    if path is None:
        return copy.deepcopy(PULSARS)
    with open(path) as f:
        return yaml.safe_load(f)["sources"]
