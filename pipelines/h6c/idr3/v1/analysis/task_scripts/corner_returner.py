import os
import numpy as np
import yaml
from hera_cal import io
from pyuvdata import UVFlag

import argparse

# create an argparser for this_file, map_yaml, and out_folder
parser = argparse.ArgumentParser()
parser.add_argument("this_file", help="this particular file, used to index into the map_yaml. Outputs will be written in the same folder.")
parser.add_argument("map_yaml_path", help="path to yaml that maps files to antpairs and antpairs to ubl keys")
parser.add_argument("extension", help='replacement for ".uvh5" for the output type to corner turn (must end in ".uvh5" for UVData or ".h5" for UVFlag).')
args = parser.parse_args()

print(f'Running corner_returner.py for {args.this_file} to make {args.this_file.replace(".uhv5", args.extension)} using {args.map_yaml_path}')
add_to_history = 'Produced by from single-baseline files with corner_returner.py with the following environment:\n'
add_to_history += '=' * 65 + '\n' + os.popen('mamba env export').read() + '=' * 65

# open the yaml file
with open(args.map_yaml_path, 'r') as file:
    corner_turn_map = yaml.unsafe_load(file)

# read original data
hd = io.HERAData(RED_AVG_FILE)
data, flags, nsamples = hd.read()

# get all full-jd files from original corner turn
all_outfiles = [outfile for outfiles in corner_turn_map['files_to_outfiles_map'].values() for outfile in outfiles][0:10] # TODO remove this

modified_bls = set([])
if args.extension.endswith('.uvh5'):
    # if extension ends with ".uvh5" it's a data file
    for outfile in all_outfiles:
        print(f"Now loading data from on {outfile.replace('.uvh5', args.extension)}.")
        hd_ct = io.HERAData(outfile.replace('.uvh5', args.extension))
        data_ct, flags_ct, nsamples_ct = hd_ct.read(times=hd.times)
        for bl in data_ct:
            assert bl not in modified_bls, f'{bl} was already modified'
            modified_bls.add(bl)
            data[bl] = data_ct[bl]
            flags[bl] = flags_ct[bl]
            nsamples[bl] = nsamples_ct[bl]

    hd.update(data=data, flags=flags, nsamples=nsamples)
    hd.history += add_to_history
    hd.write_uvh5(args.this_file.replace('.uvh5', args.extension), clobber=True)
    
elif args.extension.endswith('.h5'):
    # if extension ends with ".h5" it's a flag file
    where_inpainted = {bl: np.zeros_like(flags[bl]) for bl in flags}
    print(f"Now loading flags from on {outfile.replace('.uvh5', args.extension)}.")
    for outfile in all_outfiles:
        wip =  io.load_flags(outfile.replace('.uvh5', args.extension))
        time_indices = np.array([np.argmin(np.abs(wip.times - t)) for t in hd.times])
        for bl in wip:
            assert bl not in modified_bls, f'{bl} was already modified'
            where_inpainted[bl] = wip[bl][time_indices, :]

    hd.update(flags=where_inpainted)
    uvf = UVFlag(hd, mode='flag', copy_flags=True)
    uvf.history += add_to_history
    uvf.write(args.this_file.replace('.uvh5', args.extension), clobber=True)

else:
    raise ValueError(f'Unknown extension {args.extension}')
