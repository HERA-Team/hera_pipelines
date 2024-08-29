#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Parameters are set in the configuration file. Here we define their positions,
# which must be consisten wtih the config.
# 1 - upload_to_librarian: boolean trigger
# 2+ - filenames

upload_to_librarian="${1}"
sum_files="${@:2}"

if [ "${upload_to_librarian}" == "True" ]; then
    for fn_path in ${sum_files[@]}; do
        # get the integer portion of the JD
        
        fn="$(basename "${fn_path}")"
        jd=$(get_int_jd ${fn})

        if librarian locate-file local-rtp ${fn}; then
            echo ${fn} is already in the librarian. Skipping...
        else
            echo librarian upload local-rtp ${fn} ${jd}/${fn}
            librarian upload local-rtp ${fn} ${jd}/${fn}
            echo Finished uploading sum data to Librarian at $(date)
        fi
    done
fi
