#! /bin/bash
set -e
# Links the staged files into the night's folder and builds its makeflow.
# usage: build.sh <JD> <pipeline toml>
source "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/operations/scripts/common.sh" "$1"
toml=${2:?usage: build.sh <JD> <pipeline toml>}
mkdir -p "${NIGHT_DIR}" "${MAKEFLOW_DIR}"
ln -sfn "${RAW_DIR}"/zen.${JD}.?????.sum.uvh5 "${NIGHT_DIR}/"
cd "${MAKEFLOW_DIR}"
build_makeflow_from_config.py -c "${toml}" "${NIGHT_DIR}"/zen.${JD}.?????.sum.uvh5
