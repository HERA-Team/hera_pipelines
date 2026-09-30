# Corner turn for a block of files: writes the same whole-night single-baseline files as corner_turn_single_jd.py,
# with the same arguments and map, but reads each red_avg file once for all the antpairs of a block of files.
#
# Among the files the map assigns antpairs to (in sorted order), the file at position i with i % block_size == 0
# leads the block of files i .. i + block_size - 1: its job corner-turns every antpair assigned to those files.
# The other jobs exit immediately. files_to_antpairs_map and files_to_outfiles_map are used as they are, so every
# single-baseline file keeps its name and its downstream assignment.
import numpy as np
import yaml
import glob
import os
import sys
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("this_file", help="this particular file, used to index into the map_yaml")
parser.add_argument("map_yaml", help="name of yaml that maps files to antpairs and antpairs to ubl keys (should be in out_folder)")
parser.add_argument("out_folder", help="output folder")
parser.add_argument("--block-size", type=int, default=8,
                    help="number of consecutive files (among those with antpairs) whose antpairs one job corner-turns")
parser.add_argument("--skip-read-checks", action="store_true",
                    help="skip pyuvdata's validation checks when reading the red_avg files")
args = parser.parse_args()

# create out_folder if it doesn't exist
if not os.path.exists(args.out_folder):
    os.makedirs(args.out_folder)

# read in yaml file
yaml_path = os.path.join(args.out_folder, args.map_yaml)
with open(yaml_path, 'r') as file:
    corner_turn_map = yaml.load(file, Loader=getattr(yaml, 'CUnsafeLoader', yaml.UnsafeLoader))  # libyaml's loader is ~10x faster

# find this file's block; files outside a block's first position leave before the slow imports
this_file = os.path.abspath(args.this_file)
files_with_work = [f for f in sorted(corner_turn_map['files_to_antpairs_map'])
                   if len(corner_turn_map['files_to_antpairs_map'][f]) > 0]
if this_file not in files_with_work:
    print(f'No baselines correspond to {args.this_file}')
    sys.exit(0)
position = files_with_work.index(this_file)
if position % args.block_size != 0:
    print(f'The baselines of {args.this_file} are corner-turned by the job of '
          f'{files_with_work[position - position % args.block_size]}')
    sys.exit(0)
block_files = files_with_work[position:position + args.block_size]
antpairs_here = [ap for f in block_files for ap in corner_turn_map['files_to_antpairs_map'][f]]
outfiles_here = [of for f in block_files for of in corner_turn_map['files_to_outfiles_map'][f]]

# get files
basename_parts = os.path.basename(args.this_file).split('.')
is_digit_cumsum = np.cumsum([part.isdigit() for part in basename_parts])  # don't replace JD, but replace decimal
glob_str = '.'.join(['*' if part.isdigit() and idcs >= 2 else part for part, idcs in zip(basename_parts, is_digit_cumsum)])
all_files = [os.path.abspath(f) for f in sorted(glob.glob(os.path.join(os.path.dirname(args.this_file), glob_str)))]

import warnings
from hera_cal import utils
from pyuvdata import UVData
from pyuvdata.utils import antnums_to_baseline

run_checks = not args.skip_read_checks
read_kwargs = dict(blts_are_rectangular=True, time_axis_faster_than_bls=True,
                   run_check=run_checks, check_extra=run_checks, run_check_acceptability=run_checks)
DOWNSELECT_NOTE = '  Downselected to specific antenna pairs using pyuvdata.'


def read_block(files, antpairs):
    '''Reads every antpair in antpairs from each file (one read per file) and concatenates them along the
    baseline-time axis in file order. Files holding none of the antpairs are left out.'''
    uvs = []
    for f in files:
        try:
            with warnings.catch_warnings():
                warnings.filterwarnings('ignore', message='Antenna pair .* does not have any data associated with it')
                uv = UVData.from_file(f, bls=antpairs, **read_kwargs)
        except ValueError as err:
            if 'No baseline-times were found' not in str(err):
                raise
            continue
        if not uv.history.endswith(DOWNSELECT_NOTE):
            # every row of the file was requested, so pyuvdata read it without a select and without this note
            uv.history += DOWNSELECT_NOTE
        uvs.append(uv)
    if len(uvs) == 0:
        raise ValueError(f'None of {files[0]}... ({len(files)} files) has any of {antpairs}')
    uvs[0].fast_concat(uvs[1:], axis='blt', inplace=True, run_check=run_checks)
    return uvs[0]


def split_antpair(block, antpair):
    '''The rows of block that belong to antpair (in either orientation), as their own UVData object with the
    block's history.'''
    rows = np.nonzero(((block.ant_1_array == antpair[0]) & (block.ant_2_array == antpair[1]))
                      | ((block.ant_1_array == antpair[1]) & (block.ant_2_array == antpair[0])))[0]
    if len(rows) == 0:
        raise ValueError(f'No baseline-times were found that match criteria: {antpair} is in none of the files')
    uvd = block.copy(metadata_only=True)
    uvd.select(blt_inds=rows, keep_all_metadata=True, run_check=False)
    uvd.history = block.history
    uvd.data_array = block.data_array[rows]
    uvd.flag_array = block.flag_array[rows]
    uvd.nsample_array = block.nsample_array[rows]
    return uvd


def corner_turn_one(uvd, antpair, outfile):
    '''Renames, gap-fills and rephases one antpair's whole-night data, then writes it to outfile.'''
    # handle case where fully-flagged baselines are misordered
    is_misordered_but_flagged = (uvd.ant_1_array != np.median(uvd.ant_1_array)) | (uvd.ant_2_array != np.median(uvd.ant_2_array))
    is_misordered_but_flagged &= np.all(uvd.flag_array, axis=(1, 2))
    if np.any(is_misordered_but_flagged):
        print(f'{np.sum(is_misordered_but_flagged)} integrations have the wrong order in ant_1_array or ' +
              'ant_2_array but are flagged. Fixing them...')
        uvd.ant_1_array[is_misordered_but_flagged] = np.median(uvd.ant_1_array[~is_misordered_but_flagged]).astype(uvd.ant_1_array.dtype)
        uvd.ant_2_array[is_misordered_but_flagged] = np.median(uvd.ant_2_array[~is_misordered_but_flagged]).astype(uvd.ant_2_array.dtype)

    # compute baseline vector from the actual data ordering before renaming
    antpos = uvd.telescope.get_enu_antpos()
    bl_vec = (antpos[uvd.telescope.antenna_numbers == int(np.median(uvd.ant_1_array))]
              - antpos[uvd.telescope.antenna_numbers == int(np.median(uvd.ant_2_array))])

    # rename antennas in underlying UVData object
    ubl_key = corner_turn_map['antpairs_to_ubl_keys_map'][antpair]
    print(f'\tIdentifying {antpair} as {ubl_key} for consistency across nights.')
    if np.all(uvd.ant_1_array == antpair[0]):
        uvd.ant_1_array[:] = ubl_key[0]
        uvd.ant_2_array[:] = ubl_key[1]
        uvd.baseline_array[:] = antnums_to_baseline(ubl_key[0], ubl_key[1], Nants_telescope=uvd.Nants_telescope)
    elif np.all(uvd.ant_2_array == antpair[0]):
        uvd.ant_1_array[:] = ubl_key[1]
        uvd.ant_2_array[:] = ubl_key[0]
        uvd.baseline_array[:] = antnums_to_baseline(ubl_key[1], ubl_key[0], Nants_telescope=uvd.Nants_telescope)
    else:
        raise ValueError(f'Neither ant_1_array nor ant_2_array is all {antpair[0]}')
    uvd.Nbls = np.unique(uvd.baseline_array).size
    uvd.set_uvws_from_antenna_positions()

    # figure out whethere there are any discontinutities in time
    times = np.unique(uvd.time_array)
    diffs = np.diff(times)
    dt = np.median(diffs)
    boundaries = np.where(~np.isclose(diffs,  dt))[0] + 1
    chunks = np.split(times, boundaries)

    # Handle missing data by rephasing to a common grid, inserting flagged data as necessary
    if len(chunks) > 1:
        print(f'\tThere are {len(chunks)} contiguous sets of times:')
        for c in chunks:
            print(f'\t\tFrom {c[0]} to {c[-1]}')

        # figure out the best underlying time grid that requires a minimum of rephasing
        largest_chunk = max(chunks, key=len)
        rel_tidx_min = np.round((np.min(times) - np.min(largest_chunk)) / dt)
        rel_tidx_max = np.round((np.max(times) - np.min(largest_chunk)) / dt)
        time_grid = np.arange(rel_tidx_min, rel_tidx_max + 1) * dt + np.min(largest_chunk)

        # create new UVData object with missing times
        time_grid_indices = np.abs(time_grid[None, :] - times[:, None]).argmin(axis=1)
        new_times = np.array([t for i, t in enumerate(time_grid) if i not in set(time_grid_indices)])
        if len(new_times) > 0:  # a gap that is not a whole number of integrations can leave no slot empty
            new_uvd = UVData.new(freq_array=uvd.freq_array,
                                 polarization_array=uvd.polarization_array,
                                 times=new_times,
                                 telescope=uvd.telescope,
                                 antpairs=[(int(uvd.ant_1_array[0]), int(uvd.ant_2_array[0]))],  # the data's own orientation, so they never outvote it below
                                 vis_units=uvd.vis_units,
                                 do_blt_outer=True,  # needed when there is a single new time
                                 integration_time=np.median(uvd.integration_time),
                                 empty=True)
            new_uvd.flag_array[:] = True  # flag all new data
            new_uvd.nsample_array[:] = 0
            uvd.fast_concat(new_uvd, axis='blt', inplace=True)

        # combine new times and old, then update lsts, and enforce uniform conjugation
        if np.median(uvd.ant_1_array) < np.median(uvd.ant_2_array):
            uvd.reorder_blts(conj_convention='ant1<ant2')
        else:
            uvd.reorder_blts(conj_convention='ant2<ant1')
        uvd.time_array = time_grid
        uvd.lst_array = utils.JD2LST(uvd.time_array, *uvd.telescope.location_lat_lon_alt_degrees)

        # perform rephasing of the data that got moved to a new grid (assumes a single antpair)
        old_lsts = utils.JD2LST(times, *uvd.telescope.location_lat_lon_alt_degrees)
        lst_shift = np.zeros_like(uvd.lst_array)
        for old_lst, tgi in zip(old_lsts, time_grid_indices):
            lst_shift[tgi] = uvd.lst_array[tgi] - old_lst
        uvd.data_array = utils.lst_rephase(data=uvd.data_array[:, None, :, :],
                                           bls=bl_vec,
                                           freqs=uvd.freq_array,
                                           dlst=lst_shift,
                                           lat=uvd.telescope.location_lat_lon_alt_degrees[0],
                                           inplace=False)[:, 0, :, :]

    # Write data
    print(f'\tWriting {outfile}')
    uvd.write_uvh5(outfile, clobber=True)


print(f'Corner-turning {len(antpairs_here)} antpairs, those of {len(block_files)} files starting with {block_files[0]}.')
block = read_block(all_files, antpairs_here)
for antpair, outfile in zip(antpairs_here, outfiles_here):
    print(f'Now working on {antpair}.')
    corner_turn_one(split_antpair(block, antpair), antpair, outfile)
del block

# every single-baseline file the map assigns to this block's files must now exist
missing = [f for f in outfiles_here if not os.path.isfile(f)]
if missing:
    print(f'{len(missing)} of {len(outfiles_here)} single-baseline files not produced, starting with {missing[0]}')
    sys.exit(1)
print(f'All {len(outfiles_here)} single-baseline files assigned to this block were produced.')
