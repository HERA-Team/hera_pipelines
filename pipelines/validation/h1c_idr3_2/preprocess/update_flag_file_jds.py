from pyuvdata import UVFlag
from hera_cal import io
import numpy as np
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("epoch", type=int, help="Which epoch to make sure hand flag JDs match LST-binned JDs")
args = parser.parse_args()

data_files = sorted(glob.glob(f'/lustre/aoc/projects/hera/Validation/test-4.1.0/LSTBIN/epoch_{args.epoch}/zen.grp1.of1.LST*sum.uvh5'))
# loop over data files
for df in data_files:
    hd = io.HERAData(df)
    uvf = UVFlag(df.replace('.uvh5', '.hand_flags.h5'))
    # Make sure LSTs match
    assert np.all(np.isclose(hd.lsts, uvf.lst_array,
                             rtol=max(hd._lst_array.tols[0], uvf._lst_array.tols[0]),
                             atol=max(hd._lst_array.tols[1], uvf._lst_array.tols[1])))
    if np.all(np.isclose(hd.times, uvf.time_array,
                         rtol=max(hd._time_array.tols[0], uvf._time_array.tols[0]),
                         atol=max(hd._time_array.tols[1], uvf._time_array.tols[1]))):
        print(f'JDs already match {df} so there is no need to update them. Moving on...')
        continue

    print(f'Median data JD is {np.median(hd.times)}.')
    print(f'Median hand_flag JD is {np.median(uvf.time_array)}.')

    uvf.time_array = hd.times
    uvf.history += f'\n\nJDs updated to match {df}\n\n'
    uvf.write(df.replace('.uvh5', '.hand_flags.h5'), clobber=True)
