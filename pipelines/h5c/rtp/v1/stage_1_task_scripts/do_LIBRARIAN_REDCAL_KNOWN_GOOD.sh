#! /bin/bash
set -e

# This function uploads all redcal_known_good files to the Librarian

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - extension: Extension to be appended to the file name.
# 3 - upload_to_librarian: global boolean trigger
# 4 - librarian_redcal_known_good: boolean trigger for this step
fn="${1}"
upload_to_librarian="${2}"
librarian_ant_metrics="${3}"

bn=`basename ${fn}`
jd=$(get_int_jd ${fn})

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_redcal_known_good}" == "True" ]; then

        # Compress all redcal_known_good files into one with a JD corresponding to $fn        
        declare -a exts=(
            ".known_good.first.calfits"
            ".known_good.omni.calfits"
            ".known_good.omni_vis.uvh5"
            ".known_good.redcal_meta.hdf5"
        )
        for ext in ${exts[@]}; do
            compressed_file=`echo ${fn%.uvh5}${ext}.tar.gz`
            echo tar -czfv ${compressed_file} zen.${jd}*${ext}
            tar -czfv ${compressed_file} zen.${jd}*${ext}

            # Upload gzipped file to the librarian
            librarian_file=`basename ${compressed_file}`
            echo librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
            librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
            echo Finished uploading ${compressed_file} to the Librarian at $(date)
            
            fn_out=`echo ${fn%.uvh5}${ext}`
            echo librarian upload local-rtp ${fn_out} ${jd}/${fn_out}
            librarian upload local-rtp ${fn_out} ${jd}/${fn_out}
            echo Finished uploading ${fn_out} to the Librarian at $(date)
        done
    fi
fi
