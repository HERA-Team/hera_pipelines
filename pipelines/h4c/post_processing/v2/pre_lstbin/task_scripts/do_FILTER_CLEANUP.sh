#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

#the args are
# 1 - input file name.
# 2 - data extension.
# 3 - clear the cache containing xtalk cache files.
# 4 - clear the cache containing delay cache files.
# 5 - xtalk cache path.
# 6 - delay cache path.
# 7 - clear the delay filtered (but not xtalk filtered) files.
# 8 - label of xtalk filtered intermediate files.
# 9 - label of delay filtered intermediate files.

# define input arguments
fn="${1}"
data_ext="${2}"
label="${3}"
jd=$(get_jd $fn)
# get rid of all the waterfall files associated with this JD.
rm -rf zen.${jd}*${label}*waterfall*h5

parities=("0" "1")
sumdiff=("sum" "diff")
# remove redundantly averaged non-chunked files.
for sd in ${sumdiff[@]}
do
  for parity in ${parities[@]}
  do
    data_extp=${data_ext/.uvh5/.${parity}.uvh5}
    rm -rf zen.*.${sd}.${label}.${data_extp}
  done
done
