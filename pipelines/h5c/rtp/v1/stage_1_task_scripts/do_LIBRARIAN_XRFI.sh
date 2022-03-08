#! /bin/bash
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

        # get xrfi folder
        xrfi_folder=`echo ${fn%.sum.uvh5}.xrfi`
        xrfi_stage_1_folder=`echo ${fn%.sum.uvh5}.stage_1_xrfi`
        compressed_file=`echo ${fn%.sum.uvh5}.stage_1_xrfi.tar.gz`
        if [ -d "${xrfi_folder}" ]; then
            echo tar -czfv ${compressed_file} ${xrfi_folder}
            tar -czfv ${compressed_file} ${xrfi_folder}
            echo librarian upload local-rtp ${compressed_file} ${jd}/${xrfi_folder%.xrfi}.stage_1_xrfi.tar.gz
            librarian upload local-rtp ${compressed_file} ${jd}/${xrfi_folder%.xrfi}.stage_1_xrfi.tar.gz
        elif [ -d "${xrfi_stage_1_folder}" ]; then # if it has already been renamed
            echo tar -czfv ${compressed_file} ${xrfi_stage_1_folder}
            tar -czfv ${compressed_file} ${xrfi_stage_1_folder}
            echo librarian upload local-rtp ${compressed_file} ${jd}/${xrfi_stage_1_folder}.tar.gz
            librarian upload local-rtp ${compressed_file} ${jd}/${xrfi_stage_1_folder}.tar.gz
        fi
    fi
fi
