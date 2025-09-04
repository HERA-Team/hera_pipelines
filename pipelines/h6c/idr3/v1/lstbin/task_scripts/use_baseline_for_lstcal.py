# This script prints "True" or "False" given a baseline string and a TOML file in order to figure out 
# whether the baseline is among the most redundant NBLS_FOR_LSTCAL baselines and thus useful for LST calibration.

import argparse
import pandas as pd
import numpy as np
import toml
from hera_cal import lst_stack, io, red_groups
from hera_qm.metrics_io import read_a_priori_ant_flags
import glob

# create an argparser 
parser = argparse.ArgumentParser()
parser.add_argument("bl_str", help="the baseline string to use")
parser.add_argument("toml_file", help="the path to the toml file")
args = parser.parse_args()

# read settings
configurator = lst_stack.config.LSTBinConfiguratorSingleBaseline.from_toml(args.toml_file)
hd = io.HERAData(configurator.bl_to_file_map[list(configurator.bl_to_file_map.keys())[0]][0])
antpos = hd.antpos
toml_config = toml.load(args.toml_file)
NBLS = toml_config['LSTCAL_OPTS']['NBLS_FOR_LSTCAL']

# Julian dates for LST-calibration
jds = [int(night) for night in configurator.nights]
filepath = toml_config['FILE_CFG']['datafiles']['datadir']
aposteriori_yamls = {jd: filepath + f'/{jd}/{jd}_aposteriori_flags.yaml' for jd in jds}

data_antpos = {}
per_jd_ex_ants = {}

for jd in jds:
    file_for_loading_antpos = sorted(
        glob.glob(filepath + f"/{jd}/*.csv")
    )
    antenna_strings = pd.read_csv(file_for_loading_antpos[0], usecols=['Antenna'])['Antenna']
    data_ants = antenna_strings.str.extract(r'(\d+)')[0].astype(int).unique().tolist()
    data_antpos.update({ant: antpos[ant] for ant in data_ants})
    per_jd_ex_ants[jd] = set(read_a_priori_ant_flags(aposteriori_yamls[jd]))

keys = list(per_jd_ex_ants.keys())
shared_ex_ants = set(per_jd_ex_ants[keys[0]]).intersection(*[per_jd_ex_ants[jd] for night in keys[1:]])
unique_ex_ants = {
    key: list(set(per_jd_ex_ants[key]).difference(shared_ex_ants))
    for key in keys
}
per_jd_reds = {}
all_reds = red_groups.RedundantGroups.from_antpos(
    antpos=antpos, 
    pols=('nn', 'ee'), 
    include_autos=False
)
filtered_reds = red_groups.RedundantGroups.from_antpos(
    antpos=data_antpos, 
    pols=('nn', 'ee'), 
    include_autos=False
)
filtered_reds.filter_reds(inplace=True, ex_ants=shared_ex_ants)

for i, jd in enumerate(jds):
    reds = filtered_reds.filter_reds(inplace=False, ex_ants=unique_ex_ants[jd])
    per_jd_reds[jd] = reds

# Get the expect number of nsamples prior to reading in the files
per_jd_max_nsamples_by_bl = {}
for jd in jds:
    max_nsamples = {}
    for red in per_jd_reds[jd]:
        max_nsamples[all_reds.get_ubl_key(red[0])] = len(red)
    per_jd_max_nsamples_by_bl[jd] = max_nsamples

# Find the baselines available in all days
bls_in_all_days = set([
    red[0] for red in all_reds 
    if all(red[0] in per_jd_max_nsamples_by_bl[jd] for jd in jds)
])

for jd in jds:
    per_jd_max_nsamples_by_bl[jd] = {
        bl: per_jd_max_nsamples_by_bl[jd][bl] 
        for bl in per_jd_max_nsamples_by_bl[jd] 
        if bl in bls_in_all_days
    }

# Sum nsamples from all days
baseline_dict = {bl: 0.0 for bl in bls_in_all_days}

for jd in jds:
    blkeys = list(set(key[:2] for key in per_jd_max_nsamples_by_bl[jd]))
    for bl in bls_in_all_days:
        baseline_dict[bl] += per_jd_max_nsamples_by_bl[jd][bl]

blkeys = list(set([blkey[:2] for blkey in baseline_dict]))
nsamples = [
    baseline_dict.get(key + ('ee',), 0.0) + baseline_dict.get(key + ('nn',), 0.0)
    if (
        (baseline_dict.get(key + ('ee',), 0.0) != 0) and 
        (baseline_dict.get(key + ('nn',), 0.0) != 0)
    )
    else 0.0
    for key in blkeys
]

idx = np.argsort(nsamples)[::-1]
blkeys_for_cal = [blkeys[i] for i in idx[:NBLS]]

# print "True" or "False"
print(args.bl_str in ["{}_{}".format(*bl) for bl in blkeys_for_cal])
