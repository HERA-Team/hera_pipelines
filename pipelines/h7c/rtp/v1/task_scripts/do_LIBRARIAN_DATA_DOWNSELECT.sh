#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consisten wtih the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_downselected_data: boolean trigger for this step
fn="${1}"
upload_to_librarian="${2}"
librarian_downselected_data="${3}"

if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_downselected_data}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn})

        echo "THIS IS A PLACEHOLDER FOR ADDING DOWNSELECTED DATA TO THE LIBRARIAN. NOT CURRENTLY IMPLEMENTED."

        # get autocorrelations file
        # autos_file=`echo ${fn%.*}.autos.uvh5`

        # echo librarian upload local-rtp ${autos_file} ${jd}/${autos_file}
        # librarian upload local-rtp ${autos_file} ${jd}/${autos_file}
    fi
fi
