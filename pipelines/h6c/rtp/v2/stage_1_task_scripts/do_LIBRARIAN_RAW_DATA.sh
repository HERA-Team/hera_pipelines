#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

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

        # get the name of the diff file
        fn_diff=$(inject_diff ${fn})

        librarian locate-file local-rtp ${fn}
        if [ $? -eq 0 ]; then
            echo ${fn} is already in the librarian. Skipping...
        else
            echo librarian upload local-rtp ${fn} ${jd}/${fn}
            librarian upload local-rtp ${fn} ${jd}/${fn}
            echo Finished uploading sum data to Librarian at $(date)
        fi

        librarian locate-file local-rtp ${fn_diff}
        if [ $? -eq 0 ]; then
            echo ${fn_diff} is already in the librarian. Skipping...
        else
            echo librarian upload local-rtp ${fn_diff} ${jd}/${fn_diff}
            librarian upload local-rtp ${fn_diff} ${jd}/${fn_diff}
            echo Finished uploading diff data to Librarian at $(date)
        fi
    done
fi
