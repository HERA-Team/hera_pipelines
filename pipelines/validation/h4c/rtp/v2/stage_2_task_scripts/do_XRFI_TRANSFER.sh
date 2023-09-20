#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
fn="${1}"

#uvh5_fn=$(remove_pol $fn)
#uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software

# Use xrfi_transfer.py to bring over flags from H1C IDR 3.2
echo python ${src_dir}/xrfi_transfer.py ${uvh5_fn}
python ${src_dir}/xrfi_transfer.py ${uvh5_fn}
