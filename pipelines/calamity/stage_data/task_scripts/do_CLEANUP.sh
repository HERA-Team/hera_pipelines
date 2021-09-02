#! /bin/bash
set -e
source ${src_dir}/_common.sh

fn="${1}"

gps=$(get_gps $fn)

rm -rf ${gps}.uvfits
rm -rf ${gps}_cal.npz
