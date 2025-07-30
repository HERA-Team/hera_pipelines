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
        
        # Write data
        print(f'\tWriting {outfile}')
        uvd.write_uvh5(outfile, clobber=True)
else:
    print(f'No baselines correspond to {args.this_file}')
