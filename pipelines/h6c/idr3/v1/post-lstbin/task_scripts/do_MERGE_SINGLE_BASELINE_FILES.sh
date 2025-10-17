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

# Split the filename on the baseline pattern
# Example: zen.LST.baseline.0_0.sum.FR0filt.uvh5
basename=$(basename "$fn")

# Split before and after the baseline numbers
prefix="${basename%%.[0-9]*_[0-9]*.*}"  # Gets: zen.LST.baseline
suffix="${basename#*.[0-9]*_[0-9]*.}"   # Gets: sum.FR0filt.uvh5 (or sum.uvh5)

# Build the pattern with standard glob (works with fast-merge-baselines)
# [0-9]* matches zero or more digits, but in context it works since we have delimiters
# Replace .uvh5 with .pspec.h5
pspec_pattern="${prefix}.[0-9]*_[0-9]*.${suffix%.uvh5}.pspec.h5"

# For tavg
tavg_pattern="${prefix}.[0-9]*_[0-9]*.${suffix%.uvh5}.tavg.pspec.h5"

# Build output suffix (preserve any tags like FR0filt)
output_suffix="${suffix%.uvh5}"

# First do the non-time-averaged pspecs
pattern="$outdir/$pspec_pattern"
outpath="$outdir/baselines_merged.$output_suffix"
cmd="pspec fast-merge-baselines --pattern '${pattern}' --group stokespol --names interleave_averaged --outpath ${outpath} --extras frf_losses --batch-size 20"
echo $cmd
eval $cmd

# Check to see that output file was correctly produced
if [ -f "${outpath}.pspec.h5" ]; then
    echo Resulting ${outpath}.pspec.h5 found.
else
    echo ${outpath}.pspec.h5 not produced.
    exit 1
fi

# Now the time-averaged pspecs
pattern="$outdir/$tavg_pattern"
outpath="$outdir/baselines_merged.$output_suffix.tavg"
cmd="pspec fast-merge-baselines --pattern '${pattern}' --group stokespol --names time_and_interleave_averaged --outpath ${outpath} --extras frf_losses"
echo $cmd
eval $cmd

# Check to see that output file was correctly produced
if [ -f "${outpath}.pspec.h5" ]; then
    echo Resulting ${outpath}.pspec.h5 found.
else
    echo ${outpath}.pspec.h5 not produced.
    exit 1
fi
