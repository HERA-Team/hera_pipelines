#!/bin/bash
set -e
export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
outdir=${1}
tomlfile=${2}
outfile_idx=${3}
kernel=${4}


outname="lststack.${outfile_idx}"
 
cmd="hnote run --output-dir ${outdir} -k ${kernel} lststack -o ${outname} --toml ${tomlfile}"

echo $cmd
eval $cmd
