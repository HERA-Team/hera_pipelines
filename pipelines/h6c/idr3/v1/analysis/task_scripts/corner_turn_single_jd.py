import numpy as np
import yaml
import glob
from hera_cal import utils
from pyuvdata import FastUVH5Meta, UVData
import os
import argparse

# create an argparser for this_file, map_yaml, and out_folder
parser = argparse.ArgumentParser()
parser.add_argument("this_file", help="this particular file, used to index into the map_yaml")
parser.add_argument("map_yaml", help="name of yaml that maps files to antpairs and antpairs to ubl keys (should be in out_folder)")
parser.add_argument("out_folder", help="output folder")
args = parser.parse_args()

# create out_folder if it doesn't exist
if not os.path.exists(args.out_folder):
    os.makedirs(args.out_folder)

# get files 
basename_parts = os.path.basename(args.this_file).split('.')
is_digit_cumsum = np.cumsum([part.isdigit() for part in basename_parts])  # don't replace JD, but replace decimal
glob_str = '.'.join(['*' if part.isdigit() and idcs >= 2 else part for part, idcs in zip(basename_parts, is_digit_cumsum)])
all_files = [os.path.abspath(f) for f in sorted(glob.glob(os.path.join(os.path.dirname(args.this_file), glob_str)))]

# read in yaml file
yaml_path = os.path.join(args.out_folder, args.map_yaml)
with open(yaml_path, 'r') as file:
    corner_turn_map = yaml.unsafe_load(file)
antpairs_here = corner_turn_map['files_to_antpairs_map'][os.path.abspath(args.this_file)]
outfiles_here = corner_turn_map['files_to_outfiles_map'][os.path.abspath(args.this_file)]

# load all baselines corresponding to this_file and then write them out to uvh5
if len(antpairs_here) > 0:
    for antpair, outfile in zip(antpairs_here, outfiles_here):
        # Read for this antpair
        print(f'Now working on {antpair}.')
        usable_files = [f for f in all_files if antpair in FastUVH5Meta(f).antpairs]
        if len(usable_files) < len(all_files):
            print(f'Only {len(usable_files)} out of {len(all_files)} files have {antpair}')
        uvd = UVData.from_file(usable_files, bls=[antpair], axis='blt', 
                               blts_are_rectangular=True, time_axis_faster_than_bls=True)

        # rename antennas in underlying UVData object
        ubl_key = corner_turn_map['antpairs_to_ubl_keys_map'][antpair]
        print(f'\tIdentifying {antpair} as {ubl_key} for consistency across nights.')
        if np.all(uvd.ant_1_array == antpair[0]):
            uvd.ant_1_array[:] = ubl_key[0]
            uvd.ant_2_array[:] = ubl_key[1]
        elif np.all(uvd.ant_2_array == antpair[0]):
            uvd.ant_1_array[:] = ubl_key[1]
            uvd.ant_2_array[:] = ubl_key[0]
        else:
            raise ValueError(f'Neither ant_1_array nor ant_2_array is all {antpair[0]}')

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
            new_uvd = UVData.new(freq_array=uvd.freq_array,
                                 polarization_array=uvd.polarization_array,
                                 times=new_times,
                                 telescope=uvd.telescope,
                                 antpairs=[ubl_key],
                                 vis_units=uvd.vis_units,
                                 empty=True)
            new_uvd.flag_array[:] = True  # flag all new data
            new_uvd.nsample_array[:] = 0

            # combine new times and old, reordering to be sequential, then update 
            uvd.fast_concat(new_uvd, axis='blt', inplace=True)
            uvd.reorder_blts()
            uvd.time_array = time_grid
            uvd.lst_array = utils.JD2LST(uvd.time_array, *uvd.telescope.location_lat_lon_alt_degrees)

            # perform rephasing of the data that got moved to a new grid (assumes a single antpair)
            old_lsts = utils.JD2LST(times, *uvd.telescope.location_lat_lon_alt_degrees)
            lst_shift = np.zeros_like(uvd.lst_array)
            for old_lst, tgi in zip(old_lsts, time_grid_indices):
                lst_shift[tgi] = uvd.lst_array[tgi] - old_lst
            antpos = uvd.telescope.get_enu_antpos()
            uvd.data_array = utils.lst_rephase(data=uvd.data_array[:, None, :, :],
                                               bls=(antpos[uvd.telescope.antenna_numbers == antpair[0]] -
                                                    antpos[uvd.telescope.antenna_numbers == antpair[1]]),
                                               freqs=uvd.freq_array,
                                               dlst=lst_shift,
                                               lat=uvd.telescope.location_lat_lon_alt_degrees[0],
                                               inplace=False)[:, 0, :, :]

        # Write data
        print(f'\tWriting {outfile}')
        uvd.write_uvh5(outfile, clobber=True)
else:
    print(f'No baselines correspond to {args.this_file}')
