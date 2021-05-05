#!/bin/bash

# script to fill in missing beam file fields.

import sys
from pyuvdata import UVBeam

input = sys.argv[1] # name of input file.
output = sys.argv[2] # name of output file sans .uvh5. Will output linpol and stokes I pol beam.

output_file = output + '.fits'
pstokes_output_file = output + '_pstokes.fits'

uvbeam = UVBeam()
uvbeam.read_beamfits(input)
uvbeam.x_orientation = 'north'
uvbeam.history += f"produces with hera_pipelines/utils/make_beam_hera_pspec_compatible.py {sys.argv[1]} {sys.argv[2]}"
uvbeam.write_beamfits(output_file, clobber=True)
# convert to pstokes
uvbeam.efield_to_pstokes(inplace=True)
uvbeam.write_beamfits(pstokes_output_file, clobber=True)
