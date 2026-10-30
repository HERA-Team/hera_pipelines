#! /bin/bash
# Runs one step for one night, as the pipeline's config.toml describes it ([workflow] and [steps.<step>]), and
# records how it went in the night's state folder, so that the manager (and you, with ls) can tell what has
# happened from the files alone:
#   {state_root}/{JD}/{step}.started    when it started, on which host, as which process
#   {state_root}/{JD}/{step}.exit       its exit code and when it finished (absent while it runs)
#   {state_root}/{JD}/logs/{step}.log   everything it printed (appended to on every rerun)
# usage: OPS_CONFIG=<the pipeline's operations config.toml> step.sh <step> <JD>
#
# The step's script runs as `bash <script> <JD> [<toml>]`. It doesn't run (and the step is recorded as failed, with
# the reason in its log) until every step before it has succeeded, and, for a step after review, until the night
# has been approved. The manager runs this in a screen named {prefix}_{step}_{JD}. If the step fails there, the
# screen is left at a shell in the relevant folder, so you can attach (screen -r) to look around; run this again
# to retry.

step=$1
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "${OPS_CONFIG}" ]] || { echo "usage: OPS_CONFIG=<the pipeline's operations config.toml> step.sh <step> <JD>" >&2; exit 2; }
source "${scripts_dir}/common.sh" "$2"

# what to run, from the config: sets script, toml (or ""), makeflow (1 or 0), pipeline (its name, for mail),
# and refusal (why the step can't run yet, or "")
settings=$(python "${OPS_DIR}/manager.py" --config "${OPS_CONFIG}" step-settings "${step}" "${JD}") || exit 2
eval "${settings}"

mkdir -p "${STATE_DIR}/logs"
log="${STATE_DIR}/logs/${step}.log"
rm -f "${STATE_DIR}/${step}.exit"
echo "$(date '+%Y-%m-%dT%H:%M:%S') $(hostname) $$" > "${STATE_DIR}/${step}.started"
echo "===== ${step} ${JD}: started $(date) on $(hostname) =====" >> "${log}"

# Ctrl-C stops the step (for a makeflow, makeflow aborts its jobs) but not this wrapper, which still records how
# it ended
trap '' INT
(
    trap - INT
    [[ -z "${refusal}" ]] || die "${refusal}"
    [[ -z "${toml}" ]] || require_conda_env "${toml}"
    echo "bash ${script} ${JD} ${toml}"
    bash "${script}" "${JD}" ${toml:+"${toml}"}
) 2>&1 | tee -a "${log}"
code=${PIPESTATUS[0]}
trap - INT

echo "${code} $(date '+%Y-%m-%dT%H:%M:%S')" > "${STATE_DIR}/${step}.exit"
echo "===== ${step} ${JD}: exited ${code} at $(date) =====" | tee -a "${log}"

if [[ ${code} -eq 0 ]]; then
    mail_me "${pipeline} ${JD}: ${step} finished"
    exit 0
fi

mail_me "${pipeline} ${JD}: ${step} FAILED (exit ${code})"
if [[ -n "${OPS_SHELL_ON_FAILURE}" ]]; then
    if (( makeflow )); then
        cd "${MAKEFLOW_DIR}" 2> /dev/null
    else
        cd "${NIGHT_DIR}" 2> /dev/null || cd "${RAW_ROOT}" 2> /dev/null
    fi
    echo
    echo "${step} failed for ${JD} (log: ${log})."
    echo "This screen stays open so you can look around. To retry here: bash ${scripts_dir}/step.sh ${step} ${JD}"
    echo "Type exit (or Ctrl-D) to close it; the manager can also relaunch the step."
    exec bash -i
fi
exit ${code}
