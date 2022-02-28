#! /bin/bash
set -e

# This function uploads all ant_metrics files to the Librarian

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - extension: Extension to be appended to the file name.
# 3 - upload_to_librarian: global boolean trigger
# 4 - librarian_ant_metrics: boolean trigger for this step
fn="${1}"
extension="${2}"
upload_to_librarian="${3}"
librarian_ant_metrics="${4}"

bn=`basename ${fn}`
jd=$(get_int_jd ${fn})

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_ant_metrics}" == "True" ]; then

        # Compress all ant_metrics files into one with a JD corresponding to $fn
        compressed_file=`echo ${fn%.uvh5}${extension}.tar.gz`
        echo tar -czfv ${compressed_file} zen.${jd}*${extension}
        tar -czfv ${compressed_file} zen.${jd}*${extension}

        # Upload gzipped file to the librarian
        librarian_file=`basename ${compressed_file}`
        echo librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
        librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
        echo Finished uploading ${compressed_file} to the Librarian at $(date)
    fi
fi
