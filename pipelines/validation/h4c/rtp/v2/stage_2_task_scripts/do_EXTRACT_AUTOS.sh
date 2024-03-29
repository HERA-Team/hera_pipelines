#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
fn="${1}"

# get outfilename, removing extension and appending .autos.uvh5
uvh5_fn=${fn}
autos_file=`echo ${uvh5_fn%.*}.autos.uvh5`

echo extract_autos.py ${uvh5_fn} ${autos_file} --clobber
extract_autos.py ${uvh5_fn} ${autos_file} --clobber
