#! /bin/bash
set -e

# Reverse corner-turn: gather the per-baseline sky-model files back into all-baseline files
# with INTS_PER_OUTPUT_FILE integrations each. Invoked once per obsid; corner_return_2int.py
# uses this file's index among all input files to produce a round-robin subset of the output
# time-chunks, so collectively all chunks are produced exactly once.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
toml_file=${2}

outdir=$(cd "$(dirname "$fn")" && pwd)
cross_file="$outdir/$(basename "$fn")"

echo "Corner-returning sky-model chunks indexed by ${cross_file}"
python ${src_dir}/corner_return_2int.py ${cross_file} ${toml_file}
echo "Finished corner-returning for ${fn} at $(date)"
