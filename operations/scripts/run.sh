#! /bin/bash
set -e

# Runs one night's makeflow, or resumes it: makeflow picks up where its log says it left off, so running this
# again after a failure reruns only the jobs that failed and those that depend on them.
# usage: run.sh <JD> <pipeline toml>   (the makeflow is the one build_makeflow_from_config.py made from that toml,
#                                       in {makeflow_root}/{JD}/)
# MAX_JOBS overrides [makeflow] max_jobs, makeflow_nrao.sh's cap on simultaneous jobs.

source "$(dirname "$0")/common.sh" "$1"
toml=${2:?usage: run.sh <JD> <pipeline toml>}
makeflow=$(basename "${toml}" .toml).mf  # build_makeflow_from_config.py names the makeflow after its toml
cd "${MAKEFLOW_DIR}"
[[ -f "${makeflow}" ]] || die "there is no ${makeflow} in ${MAKEFLOW_DIR} to run"

# set the last attempt's error logs aside, so that any left at the end belong to this attempt
shopt -s nullglob
errors=(*.log.error)
shopt -u nullglob
if (( ${#errors[@]} )); then
    attempt=1
    while [[ -e previous_errors/attempt_${attempt} ]]; do attempt=$(( attempt + 1 )); done
    mkdir -p previous_errors/attempt_${attempt}
    mv "${errors[@]}" previous_errors/attempt_${attempt}/
    echo "Moved ${#errors[@]} error logs from the last attempt into previous_errors/attempt_${attempt}/"
fi

max_jobs=${MAX_JOBS:-$(cfg makeflow max_jobs)}
activate_conda_env "${toml}"  # so that makeflow, and the jobs it submits, run in the toml's conda environment
echo "Running makeflow_nrao.sh ${makeflow} ${max_jobs} in ${MAKEFLOW_DIR}, in conda environment" \
     "${CONDA_DEFAULT_ENV:-<none>}, at $(date)"
status=0
makeflow_nrao.sh "${makeflow}" "${max_jobs}" || status=$?

# makeflow ends its log with "# COMPLETED <time>" only when every job has succeeded
last_line=$(tail -n 1 "${makeflow}.makeflowlog" 2> /dev/null || true)
if [[ ${status} -eq 0 && "${last_line}" == "# COMPLETED"* ]]; then
    echo "Makeflow ${makeflow} for ${JD} completed at $(date)"
else
    shopt -s nullglob
    failed=0
    for error in *.log.error; do  # not counting jobs that makeflow retried until they succeeded (they have a .out)
        [[ -e "${error%.log.error}.out" ]] || failed=$(( failed + 1 ))
    done
    shopt -u nullglob
    die "makeflow ${makeflow} for ${JD} did not complete (exit ${status}; its log ends '${last_line:-<no log>}'; ${failed} jobs failed)"
fi
