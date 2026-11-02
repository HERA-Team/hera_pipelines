#! /bin/bash
# Stands in for hera_opm's pipeline_status.py, which fails partway through its report if FAKE_STATUS_FAILS is set.
echo "fake pipeline status report for $*"
[[ -z "${FAKE_STATUS_FAILS}" ]] || { echo "fake pipeline_status.py failed partway through" >&2; exit 1; }
echo "end of the fake report"
