#! /bin/bash
set -e
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn="${1}"

gps=$(get_gps $fn)


# remove secrets and settings.
rm -rf client_secrets.json
rm -rf settings.yaml
