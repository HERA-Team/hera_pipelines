#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

reffile="${1}"
simdir="${2}"
outdir="${3}"

python /lustre/aoc/projects/hera/Validation/H6C_IDR2/src/hera_pipelines/pipelines/validation/h6c/analysis/task_scripts/mock_lstbin_data.py \
  --sim-dir ${simdir} --ref-is-redavg \
  --outdir ${outdir} --reffile ${reffile} --clobber
