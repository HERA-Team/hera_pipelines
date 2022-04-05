from pyuvdata import UVFlag
from hera_cal import io
import numpy as np
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("file_to_truncate", type=int, help="Which file to potentially truncate, generally the final file in the epoch")
args = parser.parse_args()

# Load corresponding flag file
uvf = UVFlag(args.file_to_truncate.replace('.uvh5', '.hand_flags.h5'))

# Load data file
hd = io.HERAData(args.file_to_truncate)
d, f, n = hd.read()

# Check if times match and therefore the flag file can be applied
assert np.all(np.isclose(hd.times[0:len(uvf.time_array)], uvf.time_array,
                         rtol=max(hd._time_array.tols[0], uvf._time_array.tols[0]),
                         atol=max(hd._time_array.tols[1], uvf._time_array.tols[1])))

# Check if we need to truncate
if len(uvf.time_array) < len(hd.times):
    # Check that all truncated times are flagged, so we're not losing any data
    for bl in f:
        assert np.all(f[bl][len(uvf.time_array):, :])

    # Truncate, update history, and write file to disk
    hd.history += '\n\nManually truncated to match H1C IDR 3.2\n\n'
    hd.select(times=hd.times[0:len(uvf.time_array)])
    hd.write_uvh5(args.ffile_to_truncate, clobber=True)

    # Also truncate STD file
    hd = io.HERAData(args.file_to_truncate.replace('.LST.','.STD.'))
    d, f, n = hd.read()
    hd.history += '\n\nManually truncated to match H1C IDR 3.2\n\n'
    hd.select(times=hd.times[0:len(uvf.time_array)])
    hd.write_uvh5(args.file_to_truncate.replace('.LST.','.STD.'), clobber=True)

else:
    print(f'No need to truncate {args.file_to_truncate}')
