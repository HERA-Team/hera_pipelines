import argparse
from pyuvdata import UVCal, UVFlag

parser = argparse.ArgumentParser()
parser.add_argument("calfile", type=str, help="UVCal calibration file to add flags to. Modified in place.")
parser.add_argument("flag_file", type=str, help="UVFlag waterfall-type flag file containing flags.")

if __name__ == "__main__":
    # Parse the arguments
    args = parser.parse_args()

    # Load in the calfits file
    uvc = UVCal()
    uvc.read(args.calfile)

    # Load in the flag file
    uvf = UVFlag()
    uvf.read(args.flag_file)

    # Apply flags to calfits file. uvc.flag_array has shape (Nants, Nfreqs, Ntimes, Npols)
    # while uvf.flag_array has shape (Ntimes, Nfreqs, Npols), hence the transposition.
    uvc.flag_array |= uvf.flag_array.transpose(1, 0, 2)[None, :, :, :]
    uvc.history += f"\nRound 2 RFI flags transferred using {args.flag_file}."

    # Write out the new calfits file
    uvc.write_calfits(args.calfile, clobber=True)
