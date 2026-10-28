#! /bin/bash
set -e

# This was copied from round_2_rfi_transfer. Need to edit (still not edited fully).

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn="${1}" # sum file

echo python ${src_dir}/round_3_rfi_transfer.py ${fn%.sum.uvh5}.sum.smooth.calfits ${fn%.sum.uvh5}.sum.flag_waterfall_round_3.h5
python ${src_dir}/round_3_rfi_transfer.py ${fn%.sum.uvh5}.sum.smooth.calfits ${fn%.sum.uvh5}.sum.flag_waterfall_round_3.h5
