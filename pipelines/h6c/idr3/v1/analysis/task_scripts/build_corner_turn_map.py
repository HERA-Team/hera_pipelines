import numpy as np
import yaml
import glob
from hera_cal import io, redcal, red_groups
from pyuvdata import FastUVH5Meta
import os
import argparse

# create an argparser for this_file, map_yaml, and out_folder
parser = argparse.ArgumentParser()
parser.add_argument("this_file", help="any file in a folder of files with the same extension we want to map")
parser.add_argument("map_yaml", help="yaml that maps files to antpairs and antpairs to unique baseline keys")
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

# create yaml mapping cross files to cross antpairs
out_yaml = os.path.join(args.out_folder, args.map_yaml)

# create list of FastUVH5Meta objects and get antpairs in all files
metas = [FastUVH5Meta(f) for f in all_files]
antpairs = sorted(set([ap for meta in metas for ap in meta.antpairs]))

# create files_to_antpairs_map
files_to_antpairs_map = {file: [] for file in all_files}
for i, ap in enumerate(antpairs):
    files_to_antpairs_map[all_files[i % len(all_files)]].append(ap)

# get antpos from this file (assuming all files have the same antpos) and map antpairs to ubl_keys
hd = io.HERAData(args.this_file)
rgs = red_groups.RedundantGroups.from_antpos(hd.antpos)
antpairs_to_ubl_keys_map = {ap: rgs.get_ubl_key(ap) for ap in antpairs}

# create files_to_outfiles_map
files_to_outfiles_map = {}
for file, aps in files_to_antpairs_map.items():
    ubl_keys = [antpairs_to_ubl_keys_map[ap] for ap in aps]
    outnames = [glob_str.replace('*', f'baseline.{k[0]}_{k[1]}', 1).replace('*', '') for k in ubl_keys]
    files_to_outfiles_map[file] = [os.path.abspath(os.path.join(args.out_folder, outname)) for outname in outnames]
                                              
# write yaml
with open(out_yaml, 'w') as file:
    yaml.dump({'files_to_antpairs_map': files_to_antpairs_map, 
               'antpairs_to_ubl_keys_map': antpairs_to_ubl_keys_map,
               'files_to_outfiles_map': files_to_outfiles_map}, 
              file)

# summarize
print(f'Map created from {len(all_files)} input files (starting with {all_files[0]}) '
      f'to {len(antpairs)} antpairs and written to {out_yaml}.')