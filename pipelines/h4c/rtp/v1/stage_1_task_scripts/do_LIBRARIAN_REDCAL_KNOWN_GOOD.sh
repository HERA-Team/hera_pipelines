#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consisten wtih the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_redcal_known_good: boolean trigger for this step
fn="${1}"
upload_to_librarian="${2}"
librarian_redcal_known_good="${3}"

if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_redcal_known_good}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn})

        # upload files to librarian
        declare -a exts=(
            ".known_good.first.calfits"
            ".known_good.omni.calfits"
            ".known_good.omni_vis.uvh5"
            ".known_good.redcal_meta.hdf5"
        )
        for ext in ${exts[@]}; do
            fn_out=`echo ${fn%.uvh5}.${ext}`
            echo librarian upload local-rtp ${fn_out} ${jd}/${fn_out}
            librarian upload local-rtp ${fn_out} ${jd}/${fn_out}
        done
    fi
fi
