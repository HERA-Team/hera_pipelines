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

# clear the xtalk fragment file.
xtalk_fn=zen.${jd}.sum.${label}.xtalk_filtered_waterfall.${data_ext}
delay_fn=zen.${jd}.sum.${label}.foreground_filtered.${data_ext}

# remove per-baseline xtalk waterfall files.
echo rm -rfv ${xtalk_fn}
rm -rfv ${xtalk_fn}

# remove the delay files.
echo rm -rfv ${delay_fn}
rm -rfv ${delay_fn}

# remove even waterfalls.
xtalk_fn=zen.${jd}.even.${label}.*.xtalk_filtered_waterfall_res.${data_ext}
echo rm -rfv ${xtalk_fn}
rm -rfv ${xtalk_fn}

# remove odd waterfalls.
xtalk_fn=zen.${jd}.odd.${label}.*.xtalk_filtered_waterfall_res.${data_ext}
echo rm -rfv ${xtalk_fn}
rm -rfv ${xtalk_fn}

# remove even waterfalls.
xtalk_fn=zen.${jd}.even.${label}.*.xtalk_filtered_waterfall_filled.${data_ext}
echo rm -rfv ${xtalk_fn}
rm -rfv ${xtalk_fn}

# remove odd waterfalls.
xtalk_fn=zen.${jd}.odd.${label}.*.xtalk_filtered_waterfall_filled.${data_ext}
echo rm -rfv ${xtalk_fn}
rm -rfv ${xtalk_fn}
