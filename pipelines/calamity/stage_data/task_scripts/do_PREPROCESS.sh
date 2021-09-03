#! /bin/bash
set -e
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn="${1}"

gps=$(get_gps $fn)

echo mwa_cal_and_split.py ${gps}.uvfits ${gps}_cal.npz --phase_zenith --clobber
mwa_cal_and_split.py ${gps}.uvfits ${gps}_cal.npz --phase_zenith --clobber


rm -rf ${gps}.uvfits
rm -rf ${gps}_cal.npz
