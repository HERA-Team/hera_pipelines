# Adapted from pipelines/h6c/idr3/v1/analysis/task_scripts/corner_turn_single_jd.py
"""Corner-turn redundantly averaged data into whole-night single-baseline files.

``block_size`` is deliberately a dual bound. A leader handles at most that many
assigned map files, and its antenna pairs are read and written in batches of at
most that many pairs. This reduces repeated file opens without allowing a
single UVData read to grow beyond the per-pair block bound.
"""

import argparse
import glob
import os
import sys

import numpy as np
import yaml


def positive_int(value):
    """Argparse converter for a strictly positive block size."""
    integer = int(value)
    if integer <= 0:
        raise argparse.ArgumentTypeError("must be positive")
    return integer


def build_arg_parser():
    """Build the command-line parser without parsing arguments at import time."""
    parser = argparse.ArgumentParser()
    parser.add_argument("this_file", help="this particular file, used to index into the map_yaml")
    parser.add_argument("map_yaml", help="yaml mapping files to antenna pairs and output files")
    parser.add_argument("out_folder", help="output folder containing the corner-turn map")
    parser.add_argument(
        "--block-size", type=positive_int, default=1,
        help="maximum assigned files in a leader block and antenna pairs in each read",
    )
    parser.add_argument(
        "--skip-read-checks", action="store_true",
        help="skip pyuvdata validation checks while reading red_avg files",
    )
    return parser


def validate_corner_turn_map(corner_turn_map):
    """Check that every map assignment has one output file per antenna pair."""
    try:
        files_to_antpairs = corner_turn_map["files_to_antpairs_map"]
        files_to_outfiles = corner_turn_map["files_to_outfiles_map"]
    except KeyError as err:
        raise ValueError(f"Corner-turn map is missing {err.args[0]!r}") from err

    for filename, antpairs in files_to_antpairs.items():
        try:
            outfiles = files_to_outfiles[filename]
        except KeyError as err:
            raise ValueError(f"Corner-turn map has no outputs for {filename}") from err
        if len(antpairs) != len(outfiles):
            raise ValueError(
                f"Corner-turn map has {len(antpairs)} antenna pairs but {len(outfiles)} output files "
                f"for {filename}"
            )
    return files_to_antpairs, files_to_outfiles


def select_block_files(corner_turn_map, this_file, block_size):
    """Return a leader's files, ``None`` for a follower, or ``[]`` for no work.

    Blocks are ordered among map files with assigned antenna pairs. A file absent
    from the map is an error rather than an empty assignment.
    """
    if block_size <= 0:
        raise ValueError(f"block_size must be positive, got {block_size}")

    files_to_antpairs, _ = validate_corner_turn_map(corner_turn_map)
    this_file = os.path.abspath(this_file)
    if this_file not in files_to_antpairs:
        raise ValueError(f"{this_file} is not present in the corner-turn map")
    if not files_to_antpairs[this_file]:
        return []

    files_with_work = sorted(filename for filename, antpairs in files_to_antpairs.items() if antpairs)
    position = files_with_work.index(this_file)
    if position % block_size:
        return None
    return files_with_work[position : position + block_size]


def block_assignments(corner_turn_map, block_files):
    """Flatten a leader block into aligned antenna-pair and output-file lists."""
    files_to_antpairs, files_to_outfiles = validate_corner_turn_map(corner_turn_map)
    antpairs = [antpair for filename in block_files for antpair in files_to_antpairs[filename]]
    outfiles = [outfile for filename in block_files for outfile in files_to_outfiles[filename]]
    if len(antpairs) != len(outfiles):
        raise ValueError(
            f"Corner-turn block has {len(antpairs)} antenna pairs but {len(outfiles)} output files"
        )
    return antpairs, outfiles


def iter_read_batches(antpairs, outfiles, block_size):
    """Yield aligned antenna-pair/output batches, each no larger than ``block_size``."""
    if block_size <= 0:
        raise ValueError(f"block_size must be positive, got {block_size}")
    if len(antpairs) != len(outfiles):
        raise ValueError(
            f"Cannot corner-turn {len(antpairs)} antenna pairs into {len(outfiles)} output files"
        )
    for start in range(0, len(antpairs), block_size):
        yield antpairs[start : start + block_size], outfiles[start : start + block_size]


def matching_night_files(this_file):
    """Find the same-product red_avg files for this night."""
    basename_parts = os.path.basename(this_file).split(".")
    is_digit_cumsum = np.cumsum([part.isdigit() for part in basename_parts])
    glob_str = ".".join(
        "*" if part.isdigit() and index >= 2 else part
        for part, index in zip(basename_parts, is_digit_cumsum)
    )
    files = [
        os.path.abspath(filename)
        for filename in sorted(glob.glob(os.path.join(os.path.dirname(this_file), glob_str)))
    ]
    if not files:
        raise ValueError(f"No red_avg files matching {glob_str} were found for {this_file}")
    return files


def read_block(files, antpairs, run_check=True):
    """Read requested pairs from every useful file, concatenated in file order.

    Callers pass no more than one read batch of pairs. Files with no requested
    pairs are skipped; other read failures still propagate.
    """
    import warnings

    from pyuvdata import UVData

    if not files:
        raise ValueError("Cannot read a corner-turn block with no input files")
    if not antpairs:
        raise ValueError("Cannot read a corner-turn block with no antenna pairs")

    read_kwargs = dict(
        run_check=run_check,
        check_extra=run_check,
        run_check_acceptability=run_check,
    )
    downselect_note = "  Downselected to specific antenna pairs using pyuvdata."
    uvs = []
    for filename in files:
        try:
            with warnings.catch_warnings():
                warnings.filterwarnings(
                    "ignore", message="Antenna pair .* does not have any data associated with it"
                )
                uv = UVData.from_file(filename, bls=antpairs, **read_kwargs)
        except ValueError as err:
            if "No baseline-times were found" not in str(err):
                raise
            continue
        if not uv.history.endswith(downselect_note):
            uv.history += downselect_note
        uvs.append(uv)
    if not uvs:
        raise ValueError(
            f"None of the {len(files)} input files has any requested antenna pairs: {antpairs}"
        )
    uvs[0].fast_concat(uvs[1:], axis="blt", inplace=True, run_check=run_check)
    return uvs[0]


def split_antpair(block, antpair):
    """Return the rows of ``block`` belonging to ``antpair`` in either orientation."""
    rows = np.nonzero(
        ((block.ant_1_array == antpair[0]) & (block.ant_2_array == antpair[1]))
        | ((block.ant_1_array == antpair[1]) & (block.ant_2_array == antpair[0]))
    )[0]
    if len(rows) == 0:
        raise ValueError(f"No baseline-times were found that match criteria: {antpair}")
    uvd = block.copy(metadata_only=True)
    uvd.select(blt_inds=rows, keep_all_metadata=True, run_check=False)
    uvd.history = block.history
    uvd.data_array = block.data_array[rows]
    uvd.flag_array = block.flag_array[rows]
    uvd.nsample_array = block.nsample_array[rows]
    return uvd


def corner_turn_one(uvd, antpair, outfile, corner_turn_map=None, ubl_key=None):
    """Rename, gap-fill, rephase, and write one whole-night single-baseline file."""
    from hera_cal import utils
    from pyuvdata import UVData
    from pyuvdata.utils import antnums_to_baseline

    if ubl_key is None:
        if corner_turn_map is None:
            raise ValueError("corner_turn_one requires corner_turn_map or ubl_key")
        ubl_key = corner_turn_map["antpairs_to_ubl_keys_map"][antpair]

    is_misordered_but_flagged = (
        (uvd.ant_1_array != np.median(uvd.ant_1_array))
        | (uvd.ant_2_array != np.median(uvd.ant_2_array))
    )
    is_misordered_but_flagged &= np.all(uvd.flag_array, axis=(1, 2))
    if np.any(is_misordered_but_flagged):
        print(
            f"{np.sum(is_misordered_but_flagged)} integrations have the wrong order in ant_1_array "
            "or ant_2_array but are flagged. Fixing them..."
        )
        uvd.ant_1_array[is_misordered_but_flagged] = np.median(
            uvd.ant_1_array[~is_misordered_but_flagged]
        ).astype(uvd.ant_1_array.dtype)
        uvd.ant_2_array[is_misordered_but_flagged] = np.median(
            uvd.ant_2_array[~is_misordered_but_flagged]
        ).astype(uvd.ant_2_array.dtype)

    antpos = uvd.telescope.get_enu_antpos()
    bl_vec = (
        antpos[uvd.telescope.antenna_numbers == int(np.median(uvd.ant_1_array))]
        - antpos[uvd.telescope.antenna_numbers == int(np.median(uvd.ant_2_array))]
    )

    print(f"\tIdentifying {antpair} as {ubl_key} for consistency across nights.")
    if np.all(uvd.ant_1_array == antpair[0]):
        uvd.ant_1_array[:] = ubl_key[0]
        uvd.ant_2_array[:] = ubl_key[1]
        uvd.baseline_array[:] = antnums_to_baseline(
            ubl_key[0], ubl_key[1], Nants_telescope=uvd.Nants_telescope
        )
    elif np.all(uvd.ant_2_array == antpair[0]):
        uvd.ant_1_array[:] = ubl_key[1]
        uvd.ant_2_array[:] = ubl_key[0]
        uvd.baseline_array[:] = antnums_to_baseline(
            ubl_key[1], ubl_key[0], Nants_telescope=uvd.Nants_telescope
        )
    else:
        raise ValueError(f"Neither ant_1_array nor ant_2_array is all {antpair[0]}")
    uvd.Nbls = np.unique(uvd.baseline_array).size
    uvd.set_uvws_from_antenna_positions()

    times = np.unique(uvd.time_array)
    diffs = np.diff(times)
    dt = np.median(diffs)
    boundaries = np.where(~np.isclose(diffs, dt))[0] + 1
    chunks = np.split(times, boundaries)

    if len(chunks) > 1:
        print(f"\tThere are {len(chunks)} contiguous sets of times:")
        for chunk in chunks:
            print(f"\t\tFrom {chunk[0]} to {chunk[-1]}")

        largest_chunk = max(chunks, key=len)
        rel_tidx_min = np.round((np.min(times) - np.min(largest_chunk)) / dt)
        rel_tidx_max = np.round((np.max(times) - np.min(largest_chunk)) / dt)
        time_grid = np.arange(rel_tidx_min, rel_tidx_max + 1) * dt + np.min(largest_chunk)

        time_grid_indices = np.abs(time_grid[None, :] - times[:, None]).argmin(axis=1)
        new_times = np.array([
            time for index, time in enumerate(time_grid) if index not in set(time_grid_indices)
        ])
        if len(new_times) > 0:
            new_uvd = UVData.new(
                freq_array=uvd.freq_array,
                polarization_array=uvd.polarization_array,
                times=new_times,
                telescope=uvd.telescope,
                antpairs=[(int(uvd.ant_1_array[0]), int(uvd.ant_2_array[0]))],
                vis_units=uvd.vis_units,
                do_blt_outer=True,
                integration_time=np.median(uvd.integration_time),
                empty=True,
            )
            new_uvd.flag_array[:] = True
            new_uvd.nsample_array[:] = 0
            uvd.fast_concat(new_uvd, axis="blt", inplace=True)

        if np.median(uvd.ant_1_array) < np.median(uvd.ant_2_array):
            uvd.reorder_blts(conj_convention="ant1<ant2")
        else:
            uvd.reorder_blts(conj_convention="ant2<ant1")
        uvd.time_array = time_grid
        uvd.lst_array = utils.JD2LST(uvd.time_array, *uvd.telescope.location_lat_lon_alt_degrees)

        old_lsts = utils.JD2LST(times, *uvd.telescope.location_lat_lon_alt_degrees)
        lst_shift = np.zeros_like(uvd.lst_array)
        for old_lst, time_grid_index in zip(old_lsts, time_grid_indices):
            lst_shift[time_grid_index] = uvd.lst_array[time_grid_index] - old_lst
        uvd.data_array = utils.lst_rephase(
            data=uvd.data_array[:, None, :, :],
            bls=bl_vec,
            freqs=uvd.freq_array,
            dlst=lst_shift,
            lat=uvd.telescope.location_lat_lon_alt_degrees[0],
            inplace=False,
        )[:, 0, :, :]

    print(f"\tWriting {outfile}")
    uvd.write_uvh5(outfile, clobber=True)


def main(argv=None):
    """Run the corner turn for the leader of this file's map block."""
    args = build_arg_parser().parse_args(argv)
    os.makedirs(args.out_folder, exist_ok=True)
    yaml_path = os.path.join(args.out_folder, args.map_yaml)
    with open(yaml_path, "r") as stream:
        corner_turn_map = yaml.load(
            stream, Loader=getattr(yaml, "CUnsafeLoader", yaml.UnsafeLoader)
        )

    this_file = os.path.abspath(args.this_file)
    block_files = select_block_files(corner_turn_map, this_file, args.block_size)
    if block_files == []:
        print(f"No baselines correspond to {args.this_file}")
        return 0
    if block_files is None:
        print(f"The baselines of {args.this_file} are corner-turned by an earlier leader job.")
        return 0

    antpairs, outfiles = block_assignments(corner_turn_map, block_files)
    all_files = matching_night_files(this_file)
    print(
        f"Corner-turning {len(antpairs)} antpairs assigned to {len(block_files)} files, "
        f"reading and writing no more than {args.block_size} antpairs at a time."
    )
    for antpair_batch, outfile_batch in iter_read_batches(antpairs, outfiles, args.block_size):
        block = read_block(all_files, antpair_batch, run_check=not args.skip_read_checks)
        for antpair, outfile in zip(antpair_batch, outfile_batch):
            print(f"Now working on {antpair}.")
            corner_turn_one(
                split_antpair(block, antpair), antpair, outfile, corner_turn_map=corner_turn_map
            )
        del block

    missing = [outfile for outfile in outfiles if not os.path.isfile(outfile)]
    if missing:
        raise RuntimeError(
            f"{len(missing)} of {len(outfiles)} single-baseline files were not produced, "
            f"starting with {missing[0]}"
        )
    print(f"All {len(outfiles)} single-baseline files assigned to this block were produced.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
