#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consisten wtih the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_SSINS: boolean trigger for this step
fn="${1}"
upload_to_librarian="${2}"
librarian_SSINS="${3}"

if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_SSINS}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn})

        # get SSINS folder
        SSINS_folder=`echo ${fn%.uvh5}.SSINS`

        echo librarian upload local-rtp ${SSINS_folder} ${jd}/${SSINS_folder}
        librarian upload local-rtp ${SSINS_folder} ${jd}/${SSINS_folder}
    fi
fi
