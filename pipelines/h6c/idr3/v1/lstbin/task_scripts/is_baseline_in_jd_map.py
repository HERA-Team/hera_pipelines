# This script prints "True" or "False" given a baseline string and a TOML file in order to figure out 
# whether the baseline is mapped to a given Julian Date used for calibration

import argparse
import numpy as np
import toml

# create an argparser 
parser = argparse.ArgumentParser()
parser.add_argument("bl_str", help="the baseline string to use")
parser.add_argument("toml_file", help="the path to the toml file")
args = parser.parse_args()

configurator = LSTBinConfiguratorSingleBaseline.from_toml(args.toml_file)
all_bl_strings = sorted(list(configurator.bl_to_file_map.keys()))

bl_string_to_jd_map = {
    bl_string: night
    for night, bl_string in zip(sorted(configurator.nights), all_bl_strings)
}

print(args.bl_str in bl_string_to_jd_map)
