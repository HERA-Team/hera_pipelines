import yaml
import glob
from hera_cal import io
import os
import argparse

# create an argparser for file_glob, this_file, and out_folder
parser = argparse.ArgumentParser()
parser.add_argument("file_glob", help="glob for all files to corner turn")
parser.add_argument("this_file", help="this particular file, used to index into the file_to_baseline_map.yaml")
parser.add_argument("out_folder", help="output folder")
args = parser.parse_args()

# create out_folder if it doesn't exist
if not os.path.exists(args.out_folder):
    os.makedirs(args.out_folder)

all_files = sorted(glob.glob(args.file_glob))
out_yaml = os.path.join(os.path.dirname(args.file_glob), 'file_to_baseline_map.yaml')
hd = None
if os.path.exists(out_yaml):
    # read in yaml file if it exists
    with open(out_yaml, 'r') as file:
        files_to_bls_map = yaml.unsafe_load(file)
else:
    # create yaml file if it doesn't exist
    hd = io.HERAData(all_files)
    pols = set([bl[2] for bls in hd.bls.values() for bl in bls])
    bls = sorted(set([bl[0:2] for bls in hd.bls.values() for bl in bls]))
    files_to_bls_map = {file: [] for file in all_files}
    for i, bl in enumerate(bls):
        files_to_bls_map[all_files[i % len(all_files)]].append([bl + (pol,) for pol in pols])
    
    # write file and try to avoid collisions/race conditions
    if not os.path.exists(out_yaml):
        with open(this_file + '_temp_yaml', 'w') as file:
            yaml.dump(files_to_bls, file)
        os.rename(this_file + '_temp_yaml', out_yaml)
    
# load all baselines corresponding to this_file and then write them out to uvh5
if len(files_to_bls_map[this_file]) > 0:
    if hd is None:
        hd = io.HERAData(all_files)
    for bl_pair in files_to_bls_map[this_file]:
        hd.read(bls=bl_pair, return_data=False, axis='blt')
        outfile = os.path.join(args.out_folder, f'zen.LST.baseline.{bl_pair[0][0]}_{bl_pair[0][1]}.sum.uvh5')
        hd.write_uvh5(outfile, clobber=True)