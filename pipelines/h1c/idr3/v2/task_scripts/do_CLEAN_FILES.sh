#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# define input arguments
fn="${1}"

# remove miriad files
fn_xx=${fn}
fn_yy=$(replace_pol $fn "yy")
fn_xy=$(replace_pol $fn "xy")
fn_yx=$(replace_pol $fn "yx")
echo rm -rf "${fn_xx}"
rm -rf "${fn_xx}"
echo rm -rf "${fn_yy}"
rm -rf "${fn_yy}"
echo rm -rf "${fn_xy}"
rm -rf "${fn_xy}"
echo rm -rf "${fn_yx}"
rm -rf "${fn_yx}"

# remove uvh5 files
uvh5_fn=$(remove_pol ${fn})
uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software
echo rm -rfv ${uvh5_fn}
rm -rfv ${uvh5_fn}

# remove firstcal files
firstcal_fn=${uvh5_fn%.uvh5}.first.calfits
echo rm -rfv ${firstcal_fn}
rm -rfv ${firstcal_fn}

# remove unflagged abscal files
abscal_fn=${uvh5_fn%.uvh5}.abs.calfits
echo rm -rfv ${abscal_fn}
rm -rfv ${abscal_fn}
