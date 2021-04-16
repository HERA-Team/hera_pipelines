#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
fn="${1}"

# make outfile
outfile=${fn%.uvh5}.red_avg.uvh5

echo red_average.py ${fn} ${outfile} --redundant_average --clobber
red_average.py ${fn} ${outfile} --redundant_average --clobber
