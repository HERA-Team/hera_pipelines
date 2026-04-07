#! /bin/bash
set -euo pipefail

# Once-per-makeflow setup action for the single-baseline LST stack pipeline.
# Runs build_baseline_map.py, which writes ${LST_STACK_OPTS.OUTDIR}/baseline_map.yaml.
# All downstream per-baseline tasks read this YAML instead of recomputing
# eligibility, so the preliminary-stacked baselines and lstcal anchors are
# frozen here at the start of the run.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

toml_file=${1}

echo "BUILD_BASELINE_MAP: building baseline_map.yaml from ${toml_file}"
python3 "${src_dir}/build_baseline_map.py" "${toml_file}"
echo "BUILD_BASELINE_MAP: done at $(date)"
