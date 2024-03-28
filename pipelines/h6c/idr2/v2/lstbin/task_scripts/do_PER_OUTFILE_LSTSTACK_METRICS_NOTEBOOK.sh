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
makeplots=${5}

if [ "${makeplots}" == "True" ]
then
    makeplots="--make-plots true"
else
    makeplots="--make-plots false"
fi

outname="lststack.${outfile_idx}"

runopts="--output-dir ${outdir} -k ${kernel} --toml ${tomlfile}"
cfg="-o ${outname} --fileidx ${outfile_idx} ${makeplots}"
 
cmd="hnote run ${runopts} lststack ${cfg}"

echo $cmd
eval $cmd
