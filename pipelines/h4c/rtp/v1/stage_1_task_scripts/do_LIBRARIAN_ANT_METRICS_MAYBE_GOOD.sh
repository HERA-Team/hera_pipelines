#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consisten wtih the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_ant_metrics: boolean trigger for this step
# 4 - ant metrics extension
fn="${1}"
upload_to_librarian="${2}"
librarian_ant_metrics="${3}"
ant_metrics_extension="${4}"

if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_ant_metrics}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn})

        # get ant_metrics file
        metrics_f=`echo ${fn%.uvh5}${ant_metrics_extension}`

        echo librarian upload local-rtp ${metrics_f} ${jd}/${metrics_f}
        librarian upload local-rtp ${metrics_f} ${jd}/${metrics_f}
    fi
fi
