"""Make a mini dataset: smaller, time- and frequency-averaged versions of LST-stacked single-baseline files.

Each input file holds every LST for one baseline (e.g. zen.LST.baseline.0_1.sum.FR0filt.uvh5).
Each output file holds a contiguous block of averaged LSTs for every baseline, polarization, and
(averaged) frequency channel, e.g. mini_dataset/zen.LST.0.12345.sum.FR0filt.uvh5, where
0.12345 is the LST (in radians) of the first averaged integration in the file.

The script is meant to be run by an hera_opm "analysis" makeflow built on all of the input files with
build_mini_dataset_makeflow.py (see mini_dataset.toml). The makeflow only creates jobs for every
job_stride-th file (via stride_length), and each of those jobs writes a disjoint subset of the output files:

    Njobs = ceil(Nfiles / job_stride)
    job j (the file at sorted index j * job_stride) writes output chunks j, j + Njobs, j + 2 * Njobs, ...

Within a job, the time slice needed for an output file is read from every single-baseline file in
parallel (partial reads along the time axis), averaged, gathered, and written. Nothing else is
written to disk; outputs are written to a temporary name and then renamed, so a job that dies never
leaves a truncated output file behind. After all jobs finish, a final job run with --finalize checks
that every output file is complete, makes any that are missing, and removes leftover temporary files.

Averaging conventions:
    * Time: each block of ints_to_average consecutive integrations is rephased to the window-center
      LST and averaged with uniform weights over unflagged samples (frf.timeavg_waterfall with
      wgt_by_nsample=False). nsamples are averaged over the window (flagged samples count as 0) and
      integration_time is multiplied by ints_to_average.
    * Frequency: each block of chans_to_average channels is averaged with uniform weights over
      unflagged samples. nsamples are averaged and channel_width is set to the summed width.
    * So nsamples stays ~ the number of nights, and nsamples * integration_time * channel_width (the
      total time-bandwidth that the radiometer equation needs) is preserved. The noise variance of a
      cross-correlation can be predicted from the averaged autos as |V_ii V_jj| / (integration_time *
      channel_width * nsamples). If the input integration_time equals the input time spacing (as for
      LST-binned data), the output integration_time equals the output time spacing, so tools that infer
      dt from the time spacing get the same answer. Because the averages use uniform
      weights, this is exact where nsamples is constant within a window; where some samples in a window
      are inpainted (nsamples = 0), the predicted noise is somewhat too high.
    * Flags are ORed within each averaging window; non-finite averages are also flagged.
    * Trailing integrations that do not fill a complete time window are dropped, as are trailing
      channels that do not fill a complete frequency window.
"""

import os

# These must be set before numpy/h5py are imported. HDF5 file locking is unreliable on Lustre, and
# each worker process should use a single thread so that nproc workers don't oversubscribe the node.
os.environ.setdefault("HDF5_USE_FILE_LOCKING", "FALSE")
for _var in ["OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"]:
    os.environ.setdefault(_var, "1")

import argparse
import glob
import multiprocessing
import re
import sys
import time
import traceback

import numpy as np
import pyuvdata
from pyuvdata.uvdata.uvh5 import FastUVH5Meta

import hera_cal
from hera_cal import io, utils

BASELINE_PATTERN = re.compile(r"\.(\d+)_(\d+)\.")


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("this_file", help="Single-baseline file that this job is indexed by. All files in the same folder "
                                          "that match fname_format are used as inputs.")
    parser.add_argument("out_folder", help="Output folder. Relative paths are relative to the folder containing this_file.")
    parser.add_argument("--fname_format", type=str, default=None,
                        help='Basename format of the input files with "{bl_str}" in place of the baseline, e.g. '
                             '"zen.LST.baseline.{bl_str}.sum.FR0filt.uvh5". Default: inferred from this_file.')
    parser.add_argument("--ints_to_average", type=int, default=4, help="Number of consecutive integrations to average together.")
    parser.add_argument("--chans_to_average", type=int, default=4, help="Number of adjacent frequency channels to average together.")
    parser.add_argument("--ints_per_output_file", type=int, default=96, help="Number of averaged integrations per output file.")
    parser.add_argument("--job_stride", type=int, default=1, help="Must match the stride_length of the makeflow action, "
                                                                  "i.e. a job is run for every job_stride-th input file.")
    parser.add_argument("--nproc", type=int, default=None, help="Number of worker processes for reading and averaging. "
                                                                "Defaults to SLURM_CPUS_PER_TASK, or the number of available CPUs.")
    parser.add_argument("--lst_range", type=float, nargs=2, default=None, metavar=("LST_MIN", "LST_MAX"),
                        help="Only use integrations with LSTs in this range, in hours. LST_MIN > LST_MAX wraps through 0h.")
    parser.add_argument("--freq_range", type=float, nargs=2, default=None, metavar=("FREQ_MIN", "FREQ_MAX"),
                        help="Only use channels with frequencies in this range, in MHz.")
    parser.add_argument("--pols", type=str, nargs="+", default=None, help="Polarizations to keep. Default is all of them.")
    parser.add_argument("--skip_existing", action="store_true", help="Skip output files that already exist instead of overwriting them.")
    parser.add_argument("--finalize", action="store_true", help="Instead of writing this job's share of the outputs, check that all "
                                                                "output files exist and are complete, and make any that are not.")
    return parser.parse_args(argv)


def list_input_files(folder, fname_format):
    """Find all single-baseline files in folder that match fname_format.

    Parameters
    ----------
    folder : str
        Folder containing the single-baseline files.
    fname_format : str
        Basename format of the input files, with "{bl_str}" in place of the baseline, e.g.
        "zen.LST.baseline.{bl_str}.sum.FR0filt.uvh5".

    Returns
    -------
    files : list of str
        All matching files, sorted the same way hera_opm sorts obsids.
    out_prefix, out_suffix : str
        Output files are named out_prefix + LST + out_suffix, e.g. "zen.LST." + "0.12345" + ".sum.FR0filt.uvh5"
    file_regex : re.Pattern
        Regular expression that input basenames match.
    """
    if fname_format.count("{bl_str}") != 1:
        raise ValueError(f"fname_format must contain exactly one {{bl_str}}, got {fname_format}")
    prefix, suffix = fname_format.split("{bl_str}")
    file_regex = re.compile("^" + re.escape(prefix) + r"\d+_\d+" + re.escape(suffix) + "$")
    candidates = glob.glob(os.path.join(folder, prefix + "*_*" + suffix))
    files = [f for f in candidates if file_regex.match(os.path.basename(f))]
    # Use the same ordering as hera_opm so that file indices line up with the makeflow's stride
    try:
        from hera_opm.mf_tools import sort_obsids
        files = sort_obsids(files)
    except ImportError:
        files = sorted(files)

    # e.g. "zen.LST.baseline." -> "zen.LST.", so outputs look like zen.LST.0.12345.sum.FR0filt.uvh5
    out_prefix = prefix[:-len("baseline.")] if prefix.endswith(".baseline.") else prefix
    return files, out_prefix, suffix, file_regex


def find_input_files(this_file, fname_format=None):
    """Find all single-baseline files of the same product as this_file (i.e. matching fname_format).

    If fname_format is None, it is inferred from this_file by replacing its last ".<ant1>_<ant2>."
    with ".{bl_str}.". Otherwise this_file must match it. Returns the same as list_input_files, but
    with the regular expression as a string.
    """
    folder, basename = os.path.split(this_file)
    if fname_format is None:
        matches = list(BASELINE_PATTERN.finditer(basename))
        if len(matches) == 0:
            raise ValueError(f"Could not find a baseline of the form '.<ant1>_<ant2>.' in {basename}")
        m = matches[-1]
        fname_format = basename[:m.start()] + ".{bl_str}." + basename[m.end():]
    files, out_prefix, suffix, file_regex = list_input_files(folder, fname_format)
    if not file_regex.match(basename):
        raise ValueError(f"{basename} does not match fname_format = {fname_format}. Build the makeflow on only the files "
                         "matching fname_format (e.g. leave out any preliminary or other products), or change fname_format. "
                         "build_mini_dataset_makeflow.py does this automatically.")
    return files, out_prefix, suffix, file_regex.pattern


def get_time_grid(ref_file):
    """Return the sorted unique times (JD) and corresponding LSTs (radians) in a single-baseline file."""
    meta = FastUVH5Meta(ref_file)
    times, inds = np.unique(meta.time_array, return_index=True)
    lsts = np.asarray(meta.lst_array)[inds]
    meta.close()
    return times, lsts


def split_into_runs(inds, times):
    """Split sorted integration indices into runs that are contiguous in index and evenly spaced in time."""
    if len(inds) == 0:
        return []
    dt = np.median(np.diff(times)) if len(times) > 1 else 0
    breaks = (np.diff(inds) != 1) | (np.diff(times[inds]) > 1.5 * dt)
    return np.split(inds, np.flatnonzero(breaks) + 1)


def build_output_chunks(times, lsts, ints_to_average, ints_per_output_file, lst_range=None):
    """Group integration indices into output files.

    Returns a list of 1D index arrays (one per output file), each holding a multiple of
    ints_to_average consecutive integrations. Averaging windows never span a gap in time or the
    edge of lst_range, and incomplete windows at the end of a run are dropped.
    """
    inds = np.arange(len(times))
    if lst_range is not None:
        lst_hours = lsts * 12 / np.pi
        lo, hi = lst_range
        in_range = (lst_hours >= lo) & (lst_hours <= hi) if lo <= hi else (lst_hours >= lo) | (lst_hours <= hi)
        inds = inds[in_range]

    chunks = []
    ints_per_chunk = ints_to_average * ints_per_output_file
    for run in split_into_runs(inds, times):
        n_usable = (len(run) // ints_to_average) * ints_to_average
        run = run[:n_usable]
        chunks.extend(run[i:i + ints_per_chunk] for i in range(0, len(run), ints_per_chunk))
    return chunks


def get_channel_selection(freqs, chans_to_average, freq_range=None):
    """Return channel indices to read (a multiple of chans_to_average), or None to read all channels."""
    chans = np.arange(len(freqs))
    if freq_range is not None:
        lo, hi = np.array(freq_range) * 1e6
        chans = chans[(freqs >= lo) & (freqs <= hi)]
    n_usable = (len(chans) // chans_to_average) * chans_to_average
    if n_usable == 0:
        raise ValueError(f"Fewer than chans_to_average={chans_to_average} channels selected.")
    if n_usable < len(chans):
        print(f"Dropping the last {len(chans) - n_usable} selected channel(s) to make a multiple of {chans_to_average}.")
    chans = chans[:n_usable]
    return None if len(chans) == len(freqs) else chans


def average_waterfalls(data, flags, nsamples, ints_to_average, chans_to_average, lat):
    """Time- and frequency-average every waterfall in the DataContainers, rephasing to window-center LSTs.

    Returns averaged data, flags, and nsamples (as dicts keyed like the inputs), averaged times,
    averaged LSTs, and averaged frequencies.
    """
    n_t, n_f = ints_to_average, chans_to_average
    Ntimes, Nfreqs = len(data.times), len(data.freqs)
    Nt_out, Nf_out = Ntimes // n_t, Nfreqs // n_f
    assert Nt_out * n_t == Ntimes and Nf_out * n_f == Nfreqs

    # window-center LSTs (unwrapped so that windows straddling 0h are handled) and times
    lsts = np.unwrap(data.lsts)
    avg_lsts = np.mean(lsts.reshape(Nt_out, n_t), axis=1)
    avg_times = np.mean(np.asarray(data.times).reshape(Nt_out, n_t), axis=1)
    avg_freqs = np.mean(np.asarray(data.freqs).reshape(Nf_out, n_f), axis=1)

    # rephase every integration to the LST of the center of its averaging window
    dlst = np.repeat(avg_lsts, n_t) - lsts
    bl_vecs = {bl: data.antpos[bl[0]] - data.antpos[bl[1]] for bl in data}
    utils.lst_rephase(data, bl_vecs, data.freqs, dlst, lat=lat, inplace=True)

    avg_data, avg_flags, avg_nsamples = {}, {}, {}
    for bl in data:
        d = data[bl].reshape(Nt_out, n_t, Nfreqs)
        f = flags[bl].reshape(Nt_out, n_t, Nfreqs)
        n = nsamples[bl].reshape(Nt_out, n_t, Nfreqs)
        w = (~f).astype(float)

        # time average: uniform weights over unflagged samples, mean nsamples (flagged count as 0), OR flags
        w_t = np.sum(w, axis=1)
        d_t = np.sum(d * w, axis=1) / w_t.clip(1e-10, np.inf)
        n_t_mean = np.sum(n * w, axis=1) / n_t
        f_t = np.any(f, axis=1)

        # frequency average: uniform weights over unflagged samples, mean nsamples, OR flags
        w_f = (w_t > 0).reshape(Nt_out, Nf_out, n_f).astype(float)
        d_f = np.sum(d_t.reshape(Nt_out, Nf_out, n_f) * w_f, axis=2) / np.sum(w_f, axis=2).clip(1e-10, np.inf)
        n_f_mean = np.mean(n_t_mean.reshape(Nt_out, Nf_out, n_f), axis=2)
        f_f = np.any(f_t.reshape(Nt_out, Nf_out, n_f), axis=2)
        f_f |= ~np.isfinite(d_f)

        avg_data[bl] = d_f.astype(data[bl].dtype)
        avg_flags[bl] = f_f
        avg_nsamples[bl] = n_f_mean.astype(nsamples[bl].dtype)

    return avg_data, avg_flags, avg_nsamples, avg_times, avg_lsts % (2 * np.pi), avg_freqs


def average_one_file(task):
    """Worker: read one time slice of one single-baseline file and return it averaged as a HERAData object."""
    file_index, path, times_in, chans, pols, n_t, n_f = task
    try:
        hd = io.HERAData(path)
        data, flags, nsamples = hd.read(times=times_in, freq_chans=chans, polarizations=pols)
        if len(data.times) != len(times_in) or not np.allclose(data.times, times_in, rtol=0, atol=1e-8):
            raise ValueError(f"Times read from {path} do not match the requested time slice.")

        lat = hd.telescope.location.lat.deg
        avg_data, avg_flags, avg_nsamples, avg_times, avg_lsts, avg_freqs = average_waterfalls(
            data, flags, nsamples, n_t, n_f, lat
        )
        del data, flags, nsamples

        # shrink the HERAData object to the averaged shape, keeping all of its metadata
        window_start_times = np.asarray(times_in)[::n_t]
        orig_channel_width = np.array(hd.channel_width)
        hd.select(times=window_start_times, freq_chans=np.arange(len(avg_freqs)))
        hd.update(data=avg_data, flags=avg_flags, nsamples=avg_nsamples)

        # relabel each window by its average time and LST
        window = np.searchsorted(window_start_times, hd.time_array - 1e-8)
        assert np.allclose(window_start_times[window], hd.time_array, rtol=0, atol=1e-8)
        hd.time_array = avg_times[window]
        hd.lst_array = avg_lsts[window]
        hd.integration_time = hd.integration_time * n_t

        hd.freq_array = avg_freqs
        hd.channel_width = np.sum(orig_channel_width.reshape(len(avg_freqs), n_f), axis=1)
        return file_index, hd
    except Exception:
        raise RuntimeError(f"Failed to average {path}:\n{traceback.format_exc()}")


def combine(results):
    """Concatenate per-file averaged HERAData objects (in input file order) along the baseline-time axis.

    The objects in results are modified in place, and only the first one is returned.
    """
    hds = [hd for _, hd in sorted(results, key=lambda r: r[0])]
    out = hds[0]
    for hd in hds[1:]:
        # all inputs are written by the same pipeline; use one history so it isn't repeated once per baseline
        hd.history = out.history
        if not np.array_equal(hd.polarization_array, out.polarization_array):
            hd.reorder_pols(order=np.array([list(hd.polarization_array).index(p) for p in out.polarization_array]))
    if len(hds) > 1:
        out.fast_concat(hds[1:], axis="blt", inplace=True)
    return out


def default_nproc():
    if "SLURM_CPUS_PER_TASK" in os.environ:
        return int(os.environ["SLURM_CPUS_PER_TASK"])
    try:
        return len(os.sched_getaffinity(0))
    except AttributeError:
        return os.cpu_count()


def output_is_complete(outfile, expected_times, expected_nfreqs, min_nbls):
    """Check (from metadata only) whether outfile exists and has the expected shape and times."""
    if not os.path.exists(outfile):
        return False
    try:
        meta = FastUVH5Meta(outfile)
        ok = (meta.Ntimes == len(expected_times) and meta.Nfreqs == expected_nfreqs and meta.Nbls >= min_nbls
              and np.allclose(np.unique(meta.time_array), expected_times, rtol=0, atol=1e-8))
        meta.close()
        return ok
    except Exception:
        return False


def write_chunk(pool, nproc, files, times_in, chans, args, outfile, history, label):
    """Average one output chunk from all single-baseline files and write it to outfile."""
    print(f"\n{label}: averaging {len(times_in)} integrations from {len(files)} files with {nproc} processes.", flush=True)
    tic = time.time()
    tasks = [(i, f, times_in, chans, args.pols, args.ints_to_average, args.chans_to_average) for i, f in enumerate(files)]
    results = []
    for n_done, result in enumerate(pool.imap_unordered(average_one_file, tasks, chunksize=2), start=1):
        results.append(result)
        if n_done % 100 == 0 or n_done == len(files):
            print(f"\t{n_done}/{len(files)} files averaged ({time.time() - tic:.1f} s)", flush=True)

    hd = combine(results)
    del results  # free the per-file copies before reordering, which makes another copy of the arrays
    hd.reorder_blts(order="time", minor_order="baseline")
    hd.history += history

    print(f"\tWriting {hd.Ntimes} integrations x {hd.Nbls} baselines x {hd.Nfreqs} channels x {hd.Npols} pols "
          f"to {outfile}", flush=True)
    tmpfile = outfile + ".tmp"
    try:
        hd.write_uvh5(tmpfile, clobber=True, fix_autos=True)
        os.replace(tmpfile, outfile)
    finally:
        if os.path.exists(tmpfile):
            os.remove(tmpfile)
    print(f"\tDone in {time.time() - tic:.1f} s.", flush=True)


def main(argv=None):
    args = parse_args(argv)
    for name in ["ints_to_average", "chans_to_average", "ints_per_output_file", "job_stride"]:
        if getattr(args, name) < 1:
            raise ValueError(f"{name} must be >= 1")
    nproc = args.nproc if args.nproc is not None else default_nproc()

    # find inputs and lay out the output files
    files, out_prefix, suffix, file_pattern = find_input_files(args.this_file, args.fname_format)
    times, lsts = get_time_grid(files[0])
    chunks = build_output_chunks(times, lsts, args.ints_to_average, args.ints_per_output_file, args.lst_range)
    if len(chunks) == 0:
        raise ValueError("No complete averaging windows found. Check lst_range and ints_to_average.")
    n_jobs = int(np.ceil(len(files) / args.job_stride))
    print(f"Found {len(files)} single-baseline files with {len(times)} integrations each, "
          f"which make {len(chunks)} output files split over {n_jobs} jobs.")

    meta = FastUVH5Meta(files[0])
    freqs = np.asarray(meta.freq_array).ravel()
    meta.close()
    chans = get_channel_selection(freqs, args.chans_to_average, args.freq_range)
    n_freqs_out = (len(freqs) if chans is None else len(chans)) // args.chans_to_average

    out_folder = args.out_folder
    if not os.path.isabs(out_folder):
        out_folder = os.path.join(os.path.dirname(os.path.abspath(args.this_file)), out_folder)
    os.makedirs(out_folder, exist_ok=True)

    def outfile_for(chunk):
        first_lst = np.mean(np.unwrap(lsts[chunk[:args.ints_to_average]])) % (2 * np.pi)
        return os.path.join(out_folder, f"{out_prefix}{first_lst:.5f}{suffix}")

    def expected_times_for(chunk):
        return np.mean(times[chunk].reshape(-1, args.ints_to_average), axis=1)

    outfiles = [outfile_for(chunk) for chunk in chunks]
    if len(set(outfiles)) != len(outfiles):
        raise ValueError("Output file names are not unique; ints_per_output_file is too small to distinguish files by LST.")

    if args.finalize:
        # check every output file and (re)make any that are missing or incomplete
        todo = [c for c in range(len(chunks))
                if not output_is_complete(outfiles[c], expected_times_for(chunks[c]), n_freqs_out, len(files))]
        if len(todo) == 0:
            print(f"All {len(chunks)} output files are present and complete.")
        else:
            print(f"WARNING: {len(todo)} of {len(chunks)} output files are missing or incomplete and will be made now. "
                  "This usually means the makeflow was not built on all of the single-baseline files:\n\t"
                  + "\n\t".join(outfiles[c] for c in todo))
    else:
        # figure out which output chunks this job is responsible for
        file_index = [os.path.basename(f) for f in files].index(os.path.basename(args.this_file))
        if file_index % args.job_stride != 0:
            raise ValueError(f"{args.this_file} is file {file_index} of {len(files)} matching {file_pattern}, which is not a "
                             f"multiple of job_stride={args.job_stride}. job_stride must match the makeflow's stride_length, "
                             "and the makeflow must be built on exactly the files matching that pattern (e.g. no "
                             "preliminary or other products mixed in). build_mini_dataset_makeflow.py does both.")
        job_index = file_index // args.job_stride
        todo = list(range(job_index, len(chunks), n_jobs))
        suggested_stride = max(1, len(files) // len(chunks))
        if len(chunks) > n_jobs:
            print(f"NOTE: each job writes up to {int(np.ceil(len(chunks) / n_jobs))} output files in series. Lower job_stride "
                  f"to {suggested_stride} or less to get one output file per job.")
        elif n_jobs - len(chunks) > 1 and suggested_stride > args.job_stride:
            print(f"NOTE: {n_jobs - len(chunks)} of the {n_jobs} jobs have no output files to write. job_stride = "
                  f"{suggested_stride} would still give one output file per job, with fewer idle jobs.")
        if args.skip_existing:
            todo = [c for c in todo if not os.path.exists(outfiles[c])]
        if len(todo) == 0:
            print(f"Job {job_index} has no output files to write.")

    history = (f"\nAveraged from {len(files)} single-baseline files in {os.path.dirname(os.path.abspath(files[0]))} "
               f"matching {file_pattern} "
               f"by make_mini_dataset.py (hera_pipelines) using hera_cal {hera_cal.__version__} and pyuvdata "
               f"{pyuvdata.__version__}. Averaged {args.ints_to_average} integrations (rephased to the window-center LST) "
               f"and {args.chans_to_average} channels with uniform weights over unflagged samples. Flags are ORed within each "
               "window. nsamples are averaged in time and frequency; integration_time and channel_width are multiplied by the "
               "number of integrations and channels averaged. "
               "The history above is that of the first input file.\n")

    if len(todo) > 0:
        ctx = multiprocessing.get_context("spawn")
        with ctx.Pool(processes=nproc) as pool:
            for c in todo:
                label = (f"Output {c + 1}/{len(chunks)} (LST {lsts[chunks[c][0]] * 12 / np.pi:.4f}h to "
                         f"{lsts[chunks[c][-1]] * 12 / np.pi:.4f}h)")
                write_chunk(pool, nproc, files, times[chunks[c]], chans, args, outfiles[c], history, label)

    if args.finalize:
        incomplete = [f for c, f in enumerate(outfiles)
                      if not output_is_complete(f, expected_times_for(chunks[c]), n_freqs_out, len(files))]
        if len(incomplete) > 0:
            raise RuntimeError("These output files are still missing or incomplete:\n\t" + "\n\t".join(incomplete))
        # all MAKE_MINI_DATASET jobs are done, so any temporary files left behind are from jobs that were killed
        for f in outfiles:
            if os.path.exists(f + ".tmp"):
                print(f"Removing leftover temporary file {f}.tmp")
                os.remove(f + ".tmp")
        extras = sorted(set(glob.glob(os.path.join(out_folder, f"{out_prefix}*{suffix}"))) - set(outfiles))
        if len(extras) > 0:
            print(f"WARNING: {out_folder} also contains {len(extras)} file(s) that are not part of this mini dataset, "
                  "probably from a run with different settings:\n\t" + "\n\t".join(extras))
        print(f"\nAll {len(outfiles)} output files in {out_folder} are complete.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
