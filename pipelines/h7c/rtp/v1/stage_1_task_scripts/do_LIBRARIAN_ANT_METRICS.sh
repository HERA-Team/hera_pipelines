#! /bin/bash
set -e

# This function uploads all ant_metrics files to the Librarian

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_ant_metrics: boolean trigger for this step
fn="${1}"
upload_to_librarian="${2}"
librarian_ant_metrics="${3}"

bn=`basename ${fn}`
jd=$(get_int_jd ${fn})
decimal_jd=$(get_jd ${fn})

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_ant_metrics}" == "True" ]; then

        # Compress all ant_metrics files into one with a JD corresponding to $fn
        compressed_file=`echo ${fn%.uvh5}.ant_metrics.hdf5.tar.gz`
        echo tar czfv ${compressed_file} zen.${jd}*.ant_metrics.hdf5
        tar czfv ${compressed_file} zen.${jd}*.ant_metrics.hdf5

        # Upload gzipped file to the librarian
        librarian_file=`basename ${compressed_file}`
        echo librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
        librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
        echo Finished uploading ${compressed_file} to the Librarian at $(date)
    fi
fi
