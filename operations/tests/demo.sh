#! /bin/bash
# A demo of the manager that runs entirely on this machine, using the fake librarian, makeflow, and mail in
# tests/fake_bin/, so you can try the TUI (and see screens come and go) without touching any real data:
#
#   bash operations/tests/demo.sh [--pipeline <its operations folder>] [<folder>]   (default: a new folder in /tmp)
#
# By default it runs the toy pipeline in tests/example_pipeline/. With --pipeline (for instance
# pipelines/phase_II/idr1/v1/operations) it runs that pipeline's own steps instead, with its tests/fake_products.sh,
# if it has one, standing in for what its makeflow makes. It queues four nights (2459862's makeflow fails the first
# time; 2460100 has no diffs), turns auto mode on, and starts the TUI. Each fake makeflow takes ~20 s.
# Set DEMO_SETUP_ONLY=1 to set it up without starting the TUI.
set -e
tests_dir="$(cd "$(dirname "$0")" && pwd)"
ops_dir="$(dirname "${tests_dir}")"
pipeline=${tests_dir}/example_pipeline
if [[ "$1" == --pipeline ]]; then
    pipeline="$(cd "$2" && pwd)"
    shift 2
fi
demo=${1:-$(mktemp -d /tmp/opsdemo.XXXX)}
mkdir -p "${demo}"
demo="$(cd "${demo}" && pwd)"

if [[ ! -f "${demo}/config.toml" ]]; then
    python - "${tests_dir}" "${demo}" "${pipeline}/config.toml" << 'PYTHON'
import sys
sys.path.insert(0, sys.argv[1])
from support import write_config
write_config(sys.argv[2], sys.argv[3], poll_seconds=3, session_prefix='demo')
PYTHON
    printf '%s\n' 2459861 2459862 2459863 2460100 >> "${demo}/nights.txt"
    mkdir -p "${demo}/state" && echo on > "${demo}/state/auto_mode"
fi

export PATH="${tests_dir}/fake_bin:${PATH}" OPS_SKIP_CONDA=1
if [[ -f "${pipeline}/tests/fake_products.sh" ]]; then
    export FAKE_MAKEFLOW_PRODUCTS="${pipeline}/tests/fake_products.sh"
fi
export FAKE_STAGE_SECONDS=${FAKE_STAGE_SECONDS:-4} FAKE_JOB_SECONDS=${FAKE_JOB_SECONDS:-2} FAKE_FAIL_JDS=${FAKE_FAIL_JDS:-2459862}
echo "Demo of ${pipeline} in ${demo} (screens are named demo_*; screen -ls to see them)"
if [[ -z "${DEMO_SETUP_ONLY}" ]]; then
    exec python "${ops_dir}/tui.py" --config "${demo}/config.toml"
fi
