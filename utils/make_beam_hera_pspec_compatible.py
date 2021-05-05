#!/bin/bash

# script to fill in missing beam file fields.

import sys
from pyuvdata import pyuvbeam

input = sys.argv[1] # name of input file.
output = sys.argv[2] # name of output file sans .uvh5. Will output linpol and stokes I pol beam.

output_file = output + '.uvh5'
pstokes_output_file = output + '_pstokes.uvh5'

uvbeam = UVBeam()
uvbeam.read_beamfits(input)
uvbeam.x_orientation = 'north'
uvbeam.write_beamfits(output_file)
# convert to pstokes
uvbeam.efield_to_pstokes(inplace=True)
uvbeam.write_beamfits(pstokes_output_file)
