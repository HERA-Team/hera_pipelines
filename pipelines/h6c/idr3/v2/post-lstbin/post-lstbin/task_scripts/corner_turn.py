import yaml
import glob
from hera_cal import io
from pyuvdata import FastUVH5Meta
import os
import argparse

# create an argparser for this_file and out_folder
parser = argparse.ArgumentParser()
parser.add_argument("this_file", help="this particular file, used to index into the file_to_baseline_map.yaml")
parser.add_argument("out_folder", help="output folder")
args = parser.parse_args()

# the cornerturn makeflow should only be built on cross-baseline LST-binned files
if 'autos' in args.this_file:
    raise ValueError(f'{args.this_file} is an autocorrelation file, not a cross-correlation file.')

# create out_folder if it doesn't exist
if not os.path.exists(args.out_folder):
    os.makedirs(args.out_folder)

# get files and split into auto and cross files
glob_str = '.'.join(['*' if part.isdigit() else part for part in os.path.basename(args.this_file).split('.')])
all_files = sorted(glob.glob(os.path.join(os.path.dirname(args.this_file), glob_str)))
auto_files = sorted([f for f in all_files if 'autos' in f.split('/')[-1]])
cross_files = sorted([f for f in all_files if 'autos' not in f.split('/')[-1]])

# make sure this file is in all_files
if args.this_file not in all_files:
    raise ValueError(f'{args.this_file} not in {os.path.join(os.path.dirname(args.this_file), glob_str)}')

# if necessary, create yaml mapping cross files to cross antpairs
out_yaml = os.path.join(os.path.dirname(args.this_file), 'cross_files_to_antpairs_map.yaml')
if os.path.exists(out_yaml):
    # read in yaml file if it exists
    with open(out_yaml, 'r') as file:
        cross_files_to_aps_map = yaml.unsafe_load(file)
else:
    # create lists of FastUVH5Meta objects
    auto_bl_metas = [FastUVH5Meta(f) for f in auto_files]
    cross_bl_metas = [FastUVH5Meta(f) for f in cross_files]

    # get pols and antpairs from metas
    auto_bl_pols = set([p for meta in auto_bl_metas for p in meta.pols])
    cross_bl_pols = set([p for meta in cross_bl_metas for p in meta.pols])
    auto_bl_antpairs = set([ap for meta in auto_bl_metas for ap in meta.antpairs])
    cross_bl_antpairs = set([ap for meta in cross_bl_metas for ap in meta.antpairs])

    # sense checks
    assert sorted(auto_bl_pols) == sorted(cross_bl_pols)
    assert len(auto_bl_antpairs) == 1

    # create cross_files_to_aps_map
    cross_files_to_aps_map = {file: [] for file in cross_files}
    cross_files_to_aps_map[cross_files[0]].append(list(auto_bl_antpairs)[0])
    for i, ap in enumerate(cross_bl_antpairs):
        cross_files_to_aps_map[cross_files[(i + 1) % len(cross_files)]].append(ap)
    
    # write file and try to avoid collisions/race conditions
    if not os.path.exists(out_yaml):
        with open(args.this_file + '_temp_yaml', 'w') as file:
            yaml.dump(cross_files_to_aps_map, file)
        os.rename(args.this_file + '_temp_yaml', out_yaml)
    
# load all baselines corresponding to this_file and then write them out to uvh5
if len(cross_files_to_aps_map[args.this_file]) > 0:
    for antpair in cross_files_to_aps_map[args.this_file]:
        # Read for this antpair
        print(f'Now working on {antpair}')
        if antpair[0] == antpair[1]:
            hd = io.HERAData(auto_files)
        else:
            hd = io.HERAData(cross_files)
            usable_files = [f for f in hd.filepaths if antpair in hd.antpairs[f]]
            if len(usable_files) < len(cross_files):
                print(f'Only {len(usable_files)} out of {len(cross_files)} files have {antpair}')
                hd = io.HERAData(usable_files)
        hd.read(bls=[antpair], return_data=False, axis='blt')
        
        # Write data
        outfile = os.path.join(args.out_folder, f'zen.LST.baseline.{antpair[0]}_{antpair[1]}.sum.uvh5')
        print(f'\tWriting {outfile}')
        hd.write_uvh5(outfile, clobber=True)
else:
    print(f'No baselines correspond to {args.this_file}')
