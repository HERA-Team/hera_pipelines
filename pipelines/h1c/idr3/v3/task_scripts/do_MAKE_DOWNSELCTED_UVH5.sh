#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# define input arguments
fn="${1}"
path_to_a_priori_flags="${2}"

# combine all 4 polarizations into a single file using pyuvdata
fn_xx=${fn}
fn_yy=$(replace_pol $fn "yy")
fn_xy=$(replace_pol $fn "xy")
fn_yx=$(replace_pol $fn "yx")
fn_out=$(remove_pol $fn)
fn_out=${fn_out%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software

# merge four polarizations
echo python -c "from pyuvdata import UVData; \
                uv = UVData(); \
                uv.read([\"${fn_xx}\", \"${fn_yy}\", \"${fn_xy}\", \"${fn_yx}\"], \
                axis=\"polarization\"); \
                uv.x_orientation = 'east'; \
                uv.history += '\n\nx_orientation manually set to east\n\n'; \
                uv.write_uvh5(\"${fn_out}\", clobber=True)"
python -c "from pyuvdata import UVData; \
           uv = UVData(); \
           uv.read([\"${fn_xx}\", \"${fn_yy}\", \"${fn_xy}\", \"${fn_yx}\"], \
           axis=\"polarization\"); \
           uv.x_orientation = 'east'; \
           uv.history += '\n\nx_orientation manually set to east\n\n'; \
           uv.write_uvh5(\"${fn_out}\", clobber=True)"

# throw out flagged antennas
jd_int=$(get_int_jd `basename ${fn_out}`)
ex_ants_yaml=`echo "${path_to_a_priori_flags}/${jd_int}.yaml"`
echo throw_away_flagged_antennas.py ${fn_out} ${fn_out} --yaml_file ${ex_ants_yaml} --clobber
throw_away_flagged_antennas.py ${fn_out} ${fn_out} --yaml_file ${ex_ants_yaml} --clobber
