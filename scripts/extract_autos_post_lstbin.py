#!/usr/bin/env python
"""
Pipeline script to extract autocorrelations from chunked files into waterfall.
"""
from pyuvdata import UVData
from hera_cal._cli_tools import parse_args, run_with_profiling
import numpy as np
import argparse


def extract_autos_post_lstbin_parser():

    parser = argparse.ArgumentParser(description="Argument parser for "
                                     "autos from the chunked files into a "
                                     "waterfall file.")
    parser.add_argument("sumdiff", type=str, help="A string identifying whether"
                        " the files are sum or diff files.")
    parser.add_argument("label", type=str, help="The file label.")
    parser.add_argument("--flist", type=str, nargs="*", 
                        help="The list of chunked files.")
    parser.add_argument("--axis", type=str, default=None, required=False,
                        help="Can specify an axis for UVData.fast_concat. "
                             "Default is None, so no fast_concat.")
    parser.add_argument("--clobber", action="store_true", required=False,
                        help="Whether to overwrite an existing autos file.")
    return parser

def main(args):
    def check_for_sumdiff_label(file):
        """
        Check that a file being read is part of the intended group. Error if not,
        since something has been passed incorrectly.
        """
        if args.sumdiff not in file:
            raise ValueError(f"Supposedly processing {args.sumdiff} files but "
                             f"{args.sumdiff} not in the filename.")
        if args.label not in file:
            raise ValueError(f"Supposedly processing {args.label} files but "
                             f"{args.label} not in the filename.")
        return
    
    # Go through and find all files that have autos using metadata reads
    files_with_autos = []
    for file in args.flist:
        check_for_sumdiff_label(file)
        test_uvd = UVData.from_file(file, read_data=False)
        if np.any(test_uvd.ant_1_array == test_uvd.ant_2_array):
            files_with_autos.append(file)
    
    assert len(files_with_autos) > 0, "No files with autos found. Check inputs."

    auto_uvd = UVData.from_file(files_with_autos, ant_str="auto", axis=args.axis)
    
    # Just formatting this string so it doesn't make a long line
    prefix = "zen.LST.0.00000"
    suffix = "foreground_filled.xtalk_filtered.chunked.waterfall.autos.uvh5"
    outfile = f"{prefix}.{args.sumdiff}.{args.label}.{suffix}"
    auto_uvd.write_uvh5(outfile, clobber=args.clobber)

    return
    
parser = extract_autos_post_lstbin_parser()
args = parse_args(parser)
run_with_profiling(main, args, args)

