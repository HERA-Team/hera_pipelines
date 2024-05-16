#!/bin/bash
set -e
export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
outdir=${1}
lstconfig=${2}
tomlfile=${3}
outfile_idx=${4}
kernel=${5}

outname="lststack.${outfile_idx}"

runopts="--output-dir ${outdir} -k ${kernel} --toml ${tomlfile}"
cfg="-o ${outname} --fileconf ${lstconfig} --fileidx ${outfile_idx}"
 
cmd="hnote run ${runopts} lststack ${cfg}"

echo $cmd
eval $cmd

# If a marker file was saved indicating that plots were made, move the notebook to the 
# appropriate directory so that it can be viewed on the web.
if [ -f "${outdir}/${outname}.ipynb.hasplots" ]
then
    casename=$(basename $(builtin cd $outdir; pwd))
    htmldir="/lustre/aoc/projects/hera/h6c-analysis/IDR2/notebooks/lstbin/${casename}"
    mkdir -p "${htmldir}"
    cp "${outdir}/${outname}.html" "${htmldir}/"
    rm "${outdir}/${outname}.ipynb.hasplots"
fi