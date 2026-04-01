# This script prints "True" or "False" given a baseline string and a TOML file in order to figure out
# whether the baseline length is within the MAX_BL_LENGTH threshold.

import argparse
import numpy as np
import toml
from hera_cal import lst_stack, io

parser = argparse.ArgumentParser()
parser.add_argument("bl_str", help="the baseline string to use")
parser.add_argument("toml_file", help="the path to the toml file")
args = parser.parse_args()

# Read MAX_BL_LENGTH from TOML, default to very large value (no filtering)
toml_config = toml.load(args.toml_file)
max_bl_length = toml_config['LST_STACK_OPTS'].get('MAX_BL_LENGTH', 1e10)

# Get antpos from a data file
configurator = lst_stack.config.LSTBinConfiguratorSingleBaseline.from_toml(args.toml_file)
hd = io.HERAData(configurator.bl_to_file_map[list(configurator.bl_to_file_map.keys())[0]][0])
antpos = hd.antpos

# Parse baseline string and compute length
ant1, ant2 = [int(a) for a in args.bl_str.split('_')]
bl_length = np.linalg.norm(antpos[ant2] - antpos[ant1])

# Print result
print(bl_length <= max_bl_length)
