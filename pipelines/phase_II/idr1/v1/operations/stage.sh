#! /bin/bash
set -e

# Stages one night's raw data from the librarian onto Lustre, into {raw_root}/{JD}/, waiting until it is all there:
# the sum files, and the diff files too for nights before [staging] diff_before_jd (diffs were only recorded
# through H6C, which is also when the sky calibration notebook's use_diff defaults to true). Nights without diffs
# get RTP's antenna classifications instead (zen.{JD}.{decimal}.sum.rtp_ant_class.csv), which the sky calibration
# notebook reads in their place.
# usage: stage.sh <JD>

source "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/operations/scripts/common.sh" "$1"

function stage ()
# stage <pattern>: stage the files whose names match a librarian pattern (% is its wildcard)
{
    echo "Staging $1 into ${RAW_ROOT} at $(date)"
    librarian stage-files -w "$(cfg staging librarian)" "${RAW_ROOT}" '{"name-matches": "'"$1"'"}'
}

function stage_rtp_ant_class ()
# RTP's antenna classifications: one csv per sum file, which the librarian has either as they are, or as RTP's
# do_LIBRARIAN_CALIBRATION_NOTEBOOKS.sh uploads them (since H6C): a tarball of the night's
# zen.{JD}.{decimal}.sum.ant_class.csv files, named for its first file with .tar.gz on the end. Unpacked, they're
# renamed .rtp_ant_class.csv, so they can't be mistaken for the ant_class.csv files this pipeline makes itself.
{
    local found tarball unpack csv name
    stage "zen.${JD}.%.sum.rtp_ant_class.csv" || echo "(no luck: looking for RTP's tarball instead)"
    found=$(find "${RAW_DIR}" -maxdepth 1 -name "zen.${JD}.?????.sum.rtp_ant_class.csv" 2> /dev/null | head -n 1)
    if [[ -n "${found}" ]]; then
        return 0
    fi
    stage "zen.${JD}.%.sum.ant_class.csv.tar.gz" || true
    for tarball in "${RAW_DIR}"/zen.${JD}.?????.sum.ant_class.csv.tar.gz; do
        [[ -f "${tarball}" ]] || die "the librarian has no RTP antenna classifications for ${JD}, as they are or in a tarball"
        echo "Unpacking ${tarball}"
        unpack=$(mktemp -d "${RAW_DIR}/unpack.XXXXXX")
        tar -xzf "${tarball}" -C "${unpack}"
        find "${unpack}" -name "zen.${JD}.?????.sum.ant_class.csv" | while read -r csv; do
            name=${csv##*/}
            mv "${csv}" "${RAW_DIR}/${name%.ant_class.csv}.rtp_ant_class.csv"
        done
        rm -rf "${unpack}" "${tarball}"  # the librarian still has it
    done
}

stage "zen.${JD}.%.sum.uvh5"
with_diffs=$(( JD < $(cfg staging diff_before_jd) ))
if (( with_diffs )); then
    stage "zen.${JD}.%.diff.uvh5"
else
    stage_rtp_ant_class
fi

# The librarian puts each night's files in a folder named for it. Check that they all arrived.
n_sum=$(find "${RAW_DIR}" -maxdepth 1 -name "zen.${JD}.?????.sum.uvh5" | wc -l | tr -d ' ')
(( n_sum > 0 )) || die "no sum files arrived in ${RAW_DIR}"
echo "Found ${n_sum} sum files in ${RAW_DIR}"
if (( with_diffs )); then
    n_diff=$(find "${RAW_DIR}" -maxdepth 1 -name "zen.${JD}.?????.diff.uvh5" | wc -l | tr -d ' ')
    (( n_diff > 0 )) || die "no diff files arrived in ${RAW_DIR}"
    echo "Found ${n_diff} diff files in ${RAW_DIR}"
    if (( n_diff != n_sum )); then
        echo "WARNING: that's ${n_diff} diff files for ${n_sum} sum files. Build will stop and name the ones without a" \
             "partner unless excluded_files.txt leaves them out."
    fi
else
    n_csv=$(find "${RAW_DIR}" -maxdepth 1 -name "zen.${JD}.?????.sum.rtp_ant_class.csv" | wc -l | tr -d ' ')
    echo "Found ${n_csv} RTP antenna classifications in ${RAW_DIR}"
    if (( n_csv != n_sum )); then
        echo "WARNING: that's ${n_csv} RTP antenna classifications for ${n_sum} sum files. Build will stop and name the" \
             "sum files without one unless excluded_files.txt leaves them out."
    fi
fi
echo "Staged ${JD} at $(date)"
