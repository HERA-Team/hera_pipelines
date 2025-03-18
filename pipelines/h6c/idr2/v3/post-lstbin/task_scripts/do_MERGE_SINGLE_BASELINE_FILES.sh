#! /bin/bash
set -e

# This script generates a notebook that processes a single-baseline file, typically redundantly-averaged and
# LST-binned, through to power spectra

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2+ - various settings
fn=${1}

# --variables used by the notebook
outdir=$(cd "$(dirname "$fn")" && pwd)
pattern="$outdir/*.pspec.h5"
outpath="$outdir/baselines_merged"
full_file_path="$outdir/$(basename "$fn")"
cmd="pspec fast-merge-baselines --pattern '${pattern}' --group stokespol --names interleave_averaged --names time_and_interleave_averaged --outpath ${outpath} --extras frf_losses"
echo $cmd
eval $cmd

# Check to see that output file was correctly produced
if [ -f "${outpath}.pspec.h5" ]; then
    echo Resulting $f found.
else
    echo $f not produced.
    exit 1
fi
