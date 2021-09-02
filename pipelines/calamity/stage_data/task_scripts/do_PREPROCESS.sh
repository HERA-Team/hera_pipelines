#! /bin/bash
set -e
source ${src_dir}/_common.sh

fn="${1}"

gps=$(get_gps $fn)

echo mwa_preprocess.py ${gps}.uvfits ${gps}_cal.npz --phase_zenith --clobber
mwa_preprocess.py ${gps}.uvfits ${gps}_cal.npz --phase_zenith --clobber
