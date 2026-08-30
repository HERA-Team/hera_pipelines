#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn="${1}"
label="${2}"



jd=$(get_jd $fn)
int_jd=${jd:0:7}

redcal_file="zen.${jd}.sum.omni.calfits"
redcal_meta_file="zen.${jd}.sum.${label}.redcal_meta.median_phases.hdf5"
old_redcal_meta_file="zen.${jd}.sum.redcal_meta.hdf5"
output_file="zen.${jd}.sum.${label}.median_phases.omni.calfits"

cmd="run_update_redcal_phase_degeneracy.py ${redcal_file} ${redcal_meta_file} ${output_file} ${old_redcal_meta_file} --clobber"
echo ${cmd}
${cmd}
