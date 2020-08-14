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
clear_xtalk_cache="${3}"
clear_delay_cache="${4}"
xtalk_cache="${5}"
delay_cache="${6}"
clear_delay="${7}"
xtalk_label="${8}"
delay_label="${9}"

# clear the xtalk fragment file.
xtalk_fn=zen.${jd}.${xtalk_label}.xtalk_filtered_waterfall.${data_ext}
delay_fn=zen.${jd}.${delay_label}.foreground_filtered.${data_ext}

# remove per-baseline xtalk waterfall files.
echo rm -rfv ${xtalk_fn}
rm -rfv ${xtalk_fn}

# remove delay filtered files if requested.
if ${clear_delay}
then
    echo rm -rfv ${xtalk_fn}
    rm -rfv ${xtalk_fn}
fi

# clear xtalk cache
if ${clear_xtalk_cache}
then
    if [ -d ${xtalk_cache} ]
    then
	rm -rfv ${xtalk_cache}
    fi
fi
# clear delay cache
if ${clear_delay_cache}
then
    if [ -d ${delay_cache} ]
    then
	rm -rfv ${delay_cache}
    fi
fi
