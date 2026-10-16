# Prints the redundant-group keys the corner-turn map assigns to one redundantly averaged file,
# as a string like "0_4" for a single group or "0_4.1_5" for several, or "none" when the map gives
# this file nothing to do. Autocorrelations are left out unless --include-autos.
import yaml
import argparse

# create an argparser for the corner turn map and the file this job was handed
parser = argparse.ArgumentParser()
parser.add_argument("corner_turn_map", help="the night's corner_turn_map.yaml")
parser.add_argument("red_avg_file", help="the redundantly averaged file this job was handed")
parser.add_argument("--include-autos", action="store_true",
                    help="keep autocorrelations, for notebooks that run on them too")
args = parser.parse_args()

with open(args.corner_turn_map) as f:
    corner_turn_map = yaml.unsafe_load(f)

# one key per antpair, in map order: build_corner_turn_map.py has already refused to write a map
# in which two antpairs share a redundant group, so these cannot repeat
ubl_key = corner_turn_map['antpairs_to_ubl_keys_map']
keys = [tuple(ubl_key[ap]) for ap in corner_turn_map['files_to_antpairs_map'].get(args.red_avg_file, [])
        if args.include_autos or ubl_key[ap][0] != ubl_key[ap][1]]

print('.'.join('_'.join(str(ant) for ant in key) for key in keys) or 'none')
