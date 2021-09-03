#! /bin/bash
set -e
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn="${1}"

gps=$(get_gps $fn)

rm -rf ${gps}.uvfits
rm -rf ${gps}_cal.npz
