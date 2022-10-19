#!/bin/bash
set -e

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
meta_fn="${1}"

sum_fn_in="${meta_fn/meta.hdf5/sum.dat}"
diff_fn_in="${meta_fn/meta.hdf5/diff.dat}"
sum_fn_out="${sum_fn_in/dat/uvh5}"
diff_fn_out="${diff_fn_in/dat/uvh5}"
sum_cmd="hera_convert_uvh5.py -i $sum_fn_in -m $meta_fn -o $sum_fn_out"
diff_cmd="hera_convert_uvh5.py -i $diff_fn_in -m $meta_fn -o $diff_fn_out"
date
echo $sum_cmd
eval $sum_cmd
date
echo $diff_cmd
eval $diff_cmd

# add to M&C
cmd="mc_add_observation.py $sum_fn_out"
date
echo $cmd
eval $cmd
# add to RTP
cmd="mc_rtp_launch_record.py $sum_fn_out"
date
echo $cmd
eval $cmd
