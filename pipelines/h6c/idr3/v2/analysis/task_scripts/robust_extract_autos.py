import argparse
from pyuvdata import UVData, FastUVH5Meta
from hera_cal import utils

parser = argparse.ArgumentParser(description="Extract autocorrelations from a .uvh5 file and write to disk as a .uvh5 file," \
                                 " attempting to produce a fully flagged file if the input file is missing key fields.")
parser.add_argument("infile", type=str, help="path to .uvh5 visibility data file from which to extract autocorrelations")
parser.add_argument("outfile", type=str, help="path to .uvh5 output data file containing only autocorrelations")
parser.add_argument("--clobber", default=False, action="store_true", help='overwrites existing file at outfile')
args = parser.parse_args()

# Get metadata to extract autos
meta = FastUVH5Meta(args.infile)
auto_pols = [p for p in meta.polarization_array for p1, p2 in [utils.split_pol(utils.polnum2str(p))] if p1 == p2]
antpairs = [ap for ap in meta.antpairs if ap[0] == ap[1]]

uvd = UVData()
try:
    # read autocorrelations
    uvd.read(args.infile, bls=antpairs, polarizations=auto_pols)
except KeyError as e:
    # if we are missing key fields, we will create a new flagged UVData object with the appropriate metadata
    # this is done becuase a few files on 2459856 were discovered to be missing either nsample_array or flag_array
    import traceback
    traceback.print_exc()
    print('-' * 50 + '\nDespire the above error, still attempting create a file with 0s '
          'for data and nsamples and True for flags with the approrpriate metadata.')
    uvd = UVData.new(freq_array=meta.freq_array,
                     polarization_array=auto_pols,
                     times=meta.times,
                     telescope=meta.telescope,
                     antpairs=antpairs,
                     vis_units=meta.vis_units,
                     empty=True)
    uvd.flag_array[:] = True  # flag all new data
    uvd.nsample_array[:] = 0
    uvd.history = meta.history + '\n' + uvd.history

# write out the result
uvd.write_uvh5(args.outfile, clobber=args.clobber)
