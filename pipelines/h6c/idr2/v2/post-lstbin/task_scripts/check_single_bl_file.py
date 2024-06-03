import argparse
from hera_cal import io
import numpy as np
import sys

# argparser for getting path to file to check
parser = argparse.ArgumentParser()
parser.add_argument("file", help="single baseline file to check, performs sys.exit(1) if either polarization is completely flagged")
parser.add_argument("--skip_autos", action='store_true', help="also performs sys.exit(1) if the file contains only autocorrelations")
parser.add_argument("--skip_outriggers", action='store_true', help="also performs sys.exit(1) if one of the antennas is an outrigger")
args = parser.parse_args()

# read in file
hd = io.HERAData(args.file)
_, flags, _ = hd.read()

# check if any antenna numbers in the data are >=320 (i.e. outriggers)
if args.skip_outriggers:
    if np.any(flags.data_ants >= 320):
        print("This file contains an outrigger and so we shouldn't use it for power spectrum estimation.")
        sys.exit(1)

# check if all baselines are autocorrelaitons
if args.skip_autos:
    if np.all([bl[0] == bl[1] for bl in flags]):
        print("This file has only autocorrelations and so we shouldn't use it for power spectrum estimation.")
        sys.exit(1)

# check if either polarization is completely flagged
for pol in hd.pols:
    if np.all([flags[bl] for bl in flags if bl[2] == pol]):
        print(f"All baselines for pol {pol} are flagged, so it isn't appropriate for power spectrum estimation.")
        sys.exit(1)
