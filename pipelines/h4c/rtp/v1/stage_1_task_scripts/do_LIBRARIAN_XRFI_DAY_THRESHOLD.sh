#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consisten wtih the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_xrfi: boolean trigger for this step
fn="${1}"
upload_to_librarian="${2}"
librarian_xrfi="${3}"

if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_xrfi}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn})

        # upload all thresholded flags files
        for ff in *_stage_1_threshold_flags.h5; do
            echo librarian upload local-rtp ${ff} ${jd}/${ff} --null-obsid
            librarian upload local-rtp ${ff} ${jd}/${ff} --null-obsid
        done
    fi
fi
