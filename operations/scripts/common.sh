#! /bin/bash
# Shared by every step script, the shared ones here and each pipeline's own: reads the pipeline's operations
# config.toml, works out the night's folders, and defines a few helpers.
# usage (from a step script): source "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/operations/scripts/common.sh" <JD>
#
# Sets JD, NIGHT_DIR, MAKEFLOW_DIR, RAW_ROOT, RAW_DIR, COLD_DIR, and STATE_DIR, and OPS_DIR (this operations
# folder). The config is $OPS_CONFIG (step.sh and the manager set it), or else the config.toml beside the step
# script, so that a pipeline's own step scripts can also be run by hand from anywhere.

function die () { echo "ERROR: $*" >&2; exit 1; }

OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPS_CONFIG=${OPS_CONFIG:-$(dirname "$0")/config.toml}
[[ -f "${OPS_CONFIG}" ]] || die "no config at ${OPS_CONFIG}: set OPS_CONFIG to the pipeline's operations config.toml"
OPS_CONFIG="$(cd "$(dirname "${OPS_CONFIG}")" && pwd)/$(basename "${OPS_CONFIG}")"
export OPS_CONFIG

JD=$1
[[ "${JD}" =~ ^[0-9]{7}$ ]] || die "expected a 7-digit JD, got '${JD}'"

python -c "import toml" 2> /dev/null || \
    die "this needs a python with toml: activate the pipeline's conda environment first"

function cfg ()
# a value from the config, e.g. cfg makeflow max_jobs; paths come back absolute
{
    python - "${OPS_CONFIG}" "$1" "$2" << 'EOF'
import os, sys, toml
config, section, key = sys.argv[1:]
value = toml.load(config)[section][key]
if section == 'paths' and value and value != 'FILL_ME_IN':
    value = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(config)), value))
print(value)
EOF
}

for key in nights_root makeflow_root raw_root cold_root state_root; do
    value=$(cfg paths ${key})
    [[ -n "${value}" && "${value}" != FILL_ME_IN ]] || die "set [paths] ${key} in ${OPS_CONFIG}"
done

NIGHT_DIR=$(cfg paths nights_root)/${JD}
MAKEFLOW_DIR=$(cfg paths makeflow_root)/${JD}
RAW_ROOT=$(cfg paths raw_root)
RAW_DIR=${RAW_ROOT}/${JD}
COLD_DIR=$(cfg paths cold_root)/${JD}_analysis
STATE_DIR=$(cfg paths state_root)/${JD}

function toml_option ()
# toml_option <toml> <key>: an entry in a pipeline toml's [Options] (nothing if it has none)
{
    python -c "import toml, sys; print(toml.load(sys.argv[1])['Options'].get(sys.argv[2], ''))" "$1" "$2"
}

function require_conda_env ()
# require_conda_env <toml>: refuse unless the toml's conda environment ([Options] conda_env) is the active one.
# The manager's screens inherit it from the manager. OPS_SKIP_CONDA (for the tests) skips this, and the next.
{
    local conda_env=$(toml_option "$1" conda_env)
    if [[ -z "${OPS_SKIP_CONDA}" && "${CONDA_DEFAULT_ENV}" != "${conda_env}" ]]; then
        die "run this in the pipeline's conda environment: conda activate ${conda_env}"
    fi
}

function activate_conda_env ()
# activate_conda_env <toml>: activate the toml's conda environment as the makeflow's own job wrappers do: source
# its [Options] source_script (which sets conda up, as ~/.bashrc does), then conda activate its conda_env
{
    [[ -z "${OPS_SKIP_CONDA}" ]] || return 0
    local source_script=$(toml_option "$1" source_script) conda_env=$(toml_option "$1" conda_env)
    [[ -n "${conda_env}" ]] || return 0
    local errexit=${-//[^e]/}
    set +e  # whatever else in them fails is no matter here, so long as the environment ends up active
    [[ -z "${source_script}" ]] || source "${source_script/#\~/${HOME}}"
    conda activate "${conda_env}"
    [[ -z "${errexit}" ]] || set -e
    [[ "${CONDA_DEFAULT_ENV}" == "${conda_env}" ]] || \
        die "could not conda activate ${conda_env} (after sourcing [Options] source_script = '${source_script}')"
}

function mail_me ()
# mail_me <subject>: a one-line notification, if [manager] email is set
{
    local email=$(cfg manager email)
    if [[ -n "${email}" ]]; then
        echo "" | mail -s "$1" "${email}" || echo "(could not send mail: $1)"
    fi
}

function require_approved ()
# for the steps that delete things: refuse unless the night has been reviewed and approved
{
    [[ -f "${STATE_DIR}/approved" ]] || die "${JD} has not been approved (no ${STATE_DIR}/approved)"
}

function delete_matching ()
# delete_matching <dir> <pattern>: delete the files (not folders) directly in dir whose names match the pattern,
# without passing them all on one command line, and say how many there were
{
    local n=$(find "$1" -maxdepth 1 ! -type d -name "$2" | wc -l | tr -d ' ')
    find "$1" -maxdepth 1 ! -type d -name "$2" -delete
    echo "Deleted ${n} files matching $1/$2"
}

function delete_bundled ()
# delete_bundled <archive>: delete the files listed in <archive>.contents.txt, which exists only once the
# archive was written in full (by a makeflow's CLEANUP step, or pack below). A file that has changed since the
# archive was made is not in it as it is now, so then nothing is deleted. Once everything is gone it does nothing,
# even after archive.sh has moved the archive itself to cold storage.
{
    local archive=$1
    local contents=${archive}.contents.txt
    [[ -s "${contents}" ]] || die "${contents} is missing"
    local present=() f
    while read -r f; do
        [[ -e "${f}" ]] && present+=("${f}")
    done < "${contents}"
    if (( ${#present[@]} == 0 )); then
        echo "The files bundled in ${archive} are already deleted"
        return 0
    fi
    [[ -s "${archive}" ]] || die "${archive} is not here, but ${#present[@]} of the files it held still are"
    for f in "${present[@]}"; do
        [[ "${f}" -nt "${archive}" ]] && die "${f} has changed since ${archive} was made; not deleting its files"
    done
    printf '%s\n' "${present[@]}" | xargs rm -f
    echo "Deleted ${#present[@]} of the $(wc -l < "${contents}" | tr -d ' ') files bundled in ${archive}"
}

function pack ()
# pack <archive> <pattern>...: bundle the files in the current folder matching the patterns into archive,
# list them in <archive>.contents.txt, and then delete them. Rerun after that, it does nothing.
{
    local archive=$1; shift
    if [[ ! -f "${archive}.contents.txt" ]]; then
        local files=() pattern
        shopt -s nullglob
        for pattern in "$@"; do files+=(${pattern}); done
        shopt -u nullglob
        (( ${#files[@]} )) || die "nothing matches $* for ${archive}"
        printf '%s\n' "${files[@]}" | sort > "${archive}.contents.txt.tmp"
        tar -czf "${archive}" -T "${archive}.contents.txt.tmp"
        mv "${archive}.contents.txt.tmp" "${archive}.contents.txt"
        echo "Wrote ${archive} (${#files[@]} files)"
    fi
    delete_bundled "${archive}"
}

function pack_makeflow_folder ()
# pack_makeflow_folder <toml>: once a night's makeflow is done with, as in H6C: write hera_opm's status report for
# it, bundle its wrappers, job logs, and .out files into makeflow_{wrappers,logs,outs}.tar.gz (deleting them), and
# remove slurm's status files. Rerun after that, it does nothing.
{
    cd "${MAKEFLOW_DIR}"
    # the status report reads the wrappers and logs, so it is written once, before they are bundled (via a .tmp, so
    # that a report cut short by a failure isn't taken for a finished one on a rerun)
    if [[ ! -f pipeline_status_report_${JD}.txt ]]; then
        pipeline_status.py --config_file "$1" --working_dir "${MAKEFLOW_DIR}" > pipeline_status_report_${JD}.txt.tmp
        mv pipeline_status_report_${JD}.txt.tmp pipeline_status_report_${JD}.txt
    fi
    pack makeflow_wrappers.tar.gz 'wrapper*.sh'
    pack makeflow_logs.tar.gz 'zen*.log*'
    pack makeflow_outs.tar.gz 'zen*.out'
    rm -f slurm.status.*
    cd - > /dev/null
}
