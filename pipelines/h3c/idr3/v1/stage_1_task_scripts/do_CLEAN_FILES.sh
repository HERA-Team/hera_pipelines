#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# define input arguments
fn="${1}"

# remove sum files
echo rm -rfv ${fn}
rm -rfv ${fn}

# remove diff files
echo rm -rfv ${fn%.sum.uvh5}.diff.uvh5
rm -rfv ${fn%.sum.uvh5}.diff.uvh5