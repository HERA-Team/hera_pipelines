#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

echo "reading in inputs..."

fn="${1}" # sum file

echo python ${src_dir}/round_2_rfi_transfer.py ${fn%.sum.uvh5}.smooth.calfits ${fn%.sum.uvh5}.flag_waterfall_round_2.h5
python ${src_dir}/round_2_rfi_transfer.py ${fn%.sum.uvh5}.smooth.calfits ${fn%.sum.uvh5}.flag_waterfall_round_2.h5