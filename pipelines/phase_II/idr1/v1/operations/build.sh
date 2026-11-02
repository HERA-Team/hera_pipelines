#! /bin/bash
set -e

# Sets one night up to run: links its staged raw files (but those excluded_files.txt leaves out) into the night's
# working folder, checking that each sum has its diff (or, on nights without diffs, its RTP antenna classification),
# builds its makeflow in the night's makeflow folder, and records what it left out and the version of every
# repository it was built from.
# usage: build.sh <JD> <pipeline toml>

source "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/operations/scripts/common.sh" "$1"
toml=${2:?usage: build.sh <JD> <pipeline toml>}
makeflow=$(basename "${toml}" .toml).mf  # build_makeflow_from_config.py names the makeflow after its toml

# The notebooks read the toml named in its own [NOTEBOOK_OPTS] toml_file, so the makeflow should be built from that one.
toml_file=$(python -c "import toml, sys; print(toml.load(sys.argv[1])['NOTEBOOK_OPTS']['toml_file'])" "${toml}")
if [[ "$(cd "$(dirname "${toml_file}")" 2> /dev/null && pwd)/$(basename "${toml_file}")" != "${toml}" ]]; then
    echo "WARNING: building from ${toml}, but the notebooks will read ${toml_file}"
fi

# the files to leave out of this night, from excluded_files.txt beside the config: "{JD}  {decimal} ...  # why"
excluded_list="$(dirname "${OPS_CONFIG}")/excluded_files.txt"
excluded=()  # zen.{JD}.{decimal} of each
left_out=()  # and why, for provenance.txt
decimals_pattern='^[0-9]{5}([[:space:]]+[0-9]{5})*$'
if [[ -f "${excluded_list}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
        read -r night decimals <<< "${line%%#*}"
        if [[ -z "${night}" ]]; then
            continue
        fi
        [[ "${night}" =~ ^[0-9]{7}$ && "${decimals}" =~ ${decimals_pattern} ]] || die "${excluded_list} should give a JD and the decimals of its files to leave out on each line, not '${line}'"
        if [[ "${night}" == "${JD}" ]]; then
            why=""
            if [[ "${line}" == *'#'* ]]; then
                read -r why <<< "${line#*#}"
            fi
            for decimal in ${decimals}; do
                entry=zen.${JD}.${decimal}
                [[ -e "${RAW_DIR}/${entry}.sum.uvh5" ]] || die "${excluded_list} leaves out ${entry}, but ${RAW_DIR} has no ${entry}.sum.uvh5"
                excluded+=("${entry}")
                left_out+=("${entry}: ${why:-no reason given}")
            done
        fi
    done < "${excluded_list}"
fi

# the raw files to link (and RTP antenna classifications, if any were staged): all of them but those left out
shopt -s nullglob
staged=("${RAW_DIR}"/zen.${JD}.?????.sum.uvh5 "${RAW_DIR}"/zen.${JD}.?????.diff.uvh5 "${RAW_DIR}"/zen.${JD}.?????.sum.rtp_ant_class.csv)
shopt -u nullglob
(( ${#staged[@]} )) || die "nothing staged in ${RAW_DIR}"
raw_files=()
for f in "${staged[@]}"; do
    name=${f##*/}
    stem=${name%%.sum.*}
    stem=${stem%%.diff.*}
    [[ " ${excluded[*]} " == *" ${stem} "* ]] || raw_files+=("${f}")
done

# every sum needs its partner: on nights with diffs, its diff (and every diff its sum), and on nights without, its
# RTP antenna classification, which the sky calibration notebook reads in place of the diff
with_diffs=$(( JD < $(cfg staging diff_before_jd) ))
unpaired=()
for f in "${raw_files[@]}"; do
    case "${f}" in
        *.sum.uvh5)
            if (( with_diffs )); then
                [[ -e "${f%.sum.uvh5}.diff.uvh5" ]] || unpaired+=("${f##*/} has no diff")
            else
                [[ -e "${f%.uvh5}.rtp_ant_class.csv" ]] || unpaired+=("${f##*/} has no RTP antenna classification")
            fi
            ;;
        *.diff.uvh5)
            [[ -e "${f%.diff.uvh5}.sum.uvh5" ]] || unpaired+=("${f##*/} has no sum")
            ;;
    esac
done
if (( ${#unpaired[@]} )); then
    printf '%s\n' "${unpaired[@]:0:20}"
    (( ${#unpaired[@]} <= 20 )) || echo "... and $(( ${#unpaired[@]} - 20 )) more"
    die "${#unpaired[@]} raw files in ${RAW_DIR} have no partner: leave them out in ${excluded_list}, or stage what's missing"
fi

mkdir -p "${NIGHT_DIR}"
cd "${NIGHT_DIR}"
for stem in "${excluded[@]}"; do
    find . -maxdepth 1 -name "${stem}.*" -type l -delete  # linked by an earlier build
    made=$(find . -maxdepth 1 -name "${stem}.*")
    [[ -z "${made}" ]] || die "${NIGHT_DIR} has files made from ${stem}, which is now left out: delete them (${stem}.*) and build again"
done
for f in "${raw_files[@]}"; do
    ln -sfn "${f}" .
done
echo "Linked ${#raw_files[@]} raw files from ${RAW_DIR} into ${NIGHT_DIR}"
if (( ${#left_out[@]} )); then
    echo "Left out ${#excluded[@]} files, as ${excluded_list} says:"
    printf '  %s\n' "${left_out[@]}"
fi

# build the makeflow; rebuilding one that has already run is left as a decision to make by hand
mkdir -p "${MAKEFLOW_DIR}"
cd "${MAKEFLOW_DIR}"
if [[ -e "${makeflow}.makeflowlog" ]]; then
    die "${MAKEFLOW_DIR} has already been run (${makeflow}.makeflowlog exists). To start over, delete that folder by hand and build again."
fi
build_makeflow_from_config.py -c "${toml}" "${NIGHT_DIR}"/zen.${JD}.?????.sum.uvh5
[[ -f "${makeflow}" ]] || die "build_makeflow_from_config.py did not write ${makeflow}"

# record what this night was built from
function describe () { echo "$1: $(git -C "$1" describe --always --dirty --tags 2> /dev/null || echo 'not a git repository')"; }
{
    echo "Built $(date) on $(hostname) by $(whoami), in conda environment ${CONDA_DEFAULT_ENV}"
    echo "from ${toml}"
    if (( ${#left_out[@]} )); then
        echo "leaving out ${#excluded[@]} raw files, as ${excluded_list} says:"
        printf '  %s\n' "${left_out[@]}"
    fi
    describe "$(dirname "${toml}")"
    src_root=$(cfg paths src_root)
    if [[ -n "${src_root}" ]]; then
        for repo in "${src_root}"/*/; do
            describe "${repo%/}"
        done
    fi
} > provenance.txt
cat provenance.txt
echo "Built the makeflow for ${JD} in ${MAKEFLOW_DIR} at $(date)"
