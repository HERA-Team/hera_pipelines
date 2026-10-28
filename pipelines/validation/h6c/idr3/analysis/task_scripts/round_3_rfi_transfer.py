import argparse
from pyuvdata import UVData, UVFlag

# This was copied from round_2. Still needs to be edited, especially the flag assignment lign.

parser = argparse.ArgumentParser()
parser.add_argument("datafile", type=str, help="UVData single baseline file to add flags to. Modified in place.")
parser.add_argument("flag_file", type=str, help="UVFlag waterfall-type flag file containing flags.")

if __name__ == "__main__":
    # Parse the arguments
    args = parser.parse_args()

    # Load in the calfits file
    uvd = UVData()
    uvd.read(args.datafile)

    # Load in the flag file
    uvf = UVFlag()
    uvf.read(args.flag_file)

    # Apply flags to data file. uvd.flag_array has shape (Nblts, Nfreqs, 4)
    # while uvf.flag_array has shape (Ntimes, Nfreqs, 2).
    uvd.flag_array |= uvf.flag_array.transpose[:, :, :]
    uvd.history += f"\nRound 3 RFI flags transferred using {args.flag_file}."

    # Write out the new calfits file
    uvd.write_calfits(args.datafile, clobber=True)
