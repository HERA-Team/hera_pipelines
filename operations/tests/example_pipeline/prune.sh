#! /bin/bash
set -e
# Once the night is approved: bundles its makeflow folder, and deletes its links to the raw data and the raw data.
# usage: prune.sh <JD> <pipeline toml>
source "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/operations/scripts/common.sh" "$1"
toml=${2:?usage: prune.sh <JD> <pipeline toml>}
require_approved
pack_makeflow_folder "${toml}"
find "${NIGHT_DIR}" -maxdepth 1 -type l -name "zen.${JD}.*" -delete
[[ -d "${RAW_DIR}" ]] && delete_matching "${RAW_DIR}" "zen.${JD}.*" && rmdir "${RAW_DIR}"
echo "Pruned ${JD}"
