#! /bin/bash
set -e
# Stages one night's sum files from the (fake) librarian into {raw_root}/{JD}/.
# usage: stage.sh <JD>
source "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/operations/scripts/common.sh" "$1"
librarian stage-files -w local "${RAW_ROOT}" '{"name-matches": "zen.'"${JD}"'.%.sum.uvh5"}'
n_sum=$(find "${RAW_DIR}" -maxdepth 1 -name "zen.${JD}.?????.sum.uvh5" | wc -l | tr -d ' ')
(( n_sum > 0 )) || die "no sum files arrived in ${RAW_DIR}"
echo "Staged ${n_sum} sum files"
