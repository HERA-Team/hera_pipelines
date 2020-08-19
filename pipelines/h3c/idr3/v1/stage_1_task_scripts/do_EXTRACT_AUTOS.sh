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
autos_file=`echo ${fn%.sum.uvh5}.sum.autos.uvh5`

echo extract_autos.py ${fn} ${autos_file} --clobber
extract_autos.py ${fn} ${autos_file} --clobber

# now do the same for the diffs
diff_file=`echo ${fn%.sum.uvh5}.diff.uvh5`
diff_autos_file=`echo ${fn%.sum.uvh5}.diff.autos.uvh5`

echo extract_autos.py ${diff_file} ${diff_autos_file} --clobber
extract_autos.py ${diff_file} ${diff_autos_file} --clobber
