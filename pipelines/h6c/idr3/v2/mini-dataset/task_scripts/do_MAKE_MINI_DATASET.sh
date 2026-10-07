#! /bin/bash
set -e

# This time- and frequency-averages LST-stacked single-baseline files and writes files that each contain a
# contiguous block of averaged LSTs for all baselines, polarizations, and (averaged) frequencies.
# Each job writes a disjoint subset of the output files; jobs with nothing to do exit immediately.

src_dir="$(dirname "$0")"
echo Host: `hostname`

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - single-baseline filename
# 2 - basename format of the input files, with {bl_str} in place of the baseline
#     (e.g. zen.LST.baseline.{bl_str}.sum.FR0filt.uvh5)
# 3 - output folder (relative to the folder containing the input files, unless absolute)
# 4 - number of integrations to average together
# 5 - number of channels to average together
# 6 - number of averaged integrations per output file
# 7 - job stride (must match the stride_length of this action in the config)
# 8 - number of worker processes
# 9 - LST range in hours as "min,max", or "None" for all LSTs
# 10 - frequency range in MHz as "min,max", or "None" for all frequencies
# 11 - comma-separated polarizations to keep (e.g. "ee,nn"), or "None" for all polarizations
# 12+ - (optional) extra flags passed straight to make_mini_dataset.py, e.g. --finalize
fn=${1}
fname_format=${2}
out_folder=${3}
ints_to_average=${4}
chans_to_average=${5}
ints_per_output_file=${6}
job_stride=${7}
nproc=${8}
lst_range=${9}
freq_range=${10}
pols=${11}
extra_flags="${@:12}"

# HDF5 file locking is unreliable on Lustre
export HDF5_USE_FILE_LOCKING=FALSE

cmd="python ${src_dir}/make_mini_dataset.py ${fn} ${out_folder} \
    --fname_format ${fname_format} \
    --ints_to_average ${ints_to_average} \
    --chans_to_average ${chans_to_average} \
    --ints_per_output_file ${ints_per_output_file} \
    --job_stride ${job_stride} \
    --nproc ${nproc}"
if [ "${lst_range}" != "None" ]; then
    cmd="${cmd} --lst_range ${lst_range//,/ }"
fi
if [ "${freq_range}" != "None" ]; then
    cmd="${cmd} --freq_range ${freq_range//,/ }"
fi
if [ "${pols}" != "None" ]; then
    cmd="${cmd} --pols ${pols//,/ }"
fi

if [ -n "${extra_flags}" ]; then
    cmd="${cmd} ${extra_flags}"
fi

echo ${cmd}
${cmd}
