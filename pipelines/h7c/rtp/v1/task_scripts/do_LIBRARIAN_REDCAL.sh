#! /bin/bash
set -e

# This function uploads all redcal files to the Librarian

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_redcal: boolean trigger for this step
fn="${1}"
upload_to_librarian="${2}"
librarian_redcal="${3}"

bn=`basename ${fn}`
jd=$(get_int_jd ${fn})

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_redcal}" == "True" ]; then

        # Compress all redcal files per output type into one with a JD corresponding to $fn
        declare -a exts=(
            ".omni.calfits"
            ".omni_vis.uvh5"
        )
        for ext in ${exts[@]}; do
            compressed_file=`echo ${fn%.uvh5}${ext}.tar.gz`
            echo tar czfv ${compressed_file} zen.${jd}*${ext}
            tar czfv ${compressed_file} zen.${jd}*${ext}

            # Upload gzipped file to the librarian
            librarian_file=`basename ${compressed_file}`
            echo librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
            librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
            echo Finished uploading ${compressed_file} to the Librarian at $(date)
        done
    fi
fi
echo Finished running librarian redcal at $(date)
