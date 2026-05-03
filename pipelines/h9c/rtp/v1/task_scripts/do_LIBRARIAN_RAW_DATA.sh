#! /bin/bash
set -e

# Import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - upload_to_librarian: boolean trigger
# 2+ - filenames

upload_to_librarian="${1}"
sum_files="${@:2}"

if [ "${upload_to_librarian}" == "True" ]; then
    for fn_path in ${sum_files[@]}; do
        # Get the integer portion of the JD
        fn="$(basename "${fn_path}")"
        jd=$(get_int_jd ${fn})

        if librarian locate-file local-rtp ${fn}; then
            echo "${fn} is already in the librarian. Skipping..."
        else
            echo librarian upload local-rtp ${fn} ${jd}/${fn}
            librarian upload local-rtp ${fn} ${jd}/${fn}
            echo "Finished uploading sum data to Librarian at $(date)"
        fi

        if librarian locate-file local-rtp ${fn%.sum.uvh5}.diff.32chansum.uvh5; then
            echo "${fn%.sum.uvh5}.diff.32chansum.uvh5 is already in the librarian. Skipping..."
        else
            # Upload a 32-channel summed version of the diff file
            diff_sum_file=$(python -c "
import numpy as np
from pyuvdata import UVData
import hdf5plugin

SUM_FILE = '${fn_path}'

# Load the file
uvd = UVData()
uvd.read(SUM_FILE.replace('.sum.', '.diff.'))

# Perform channel summation
uvd_out = uvd.select(freq_chans=np.arange(0, uvd.Nfreqs, 32), inplace=False)
uvd_out.data_array = np.sum(uvd.data_array.reshape(uvd.Nblts, -1, 32, uvd.Npols), axis=2)
uvd_out.freq_array = np.mean(uvd.freq_array.reshape(-1, 32), axis=1)

# Write the output file
output_file = SUM_FILE.replace('.sum.', '.diff.32chansum.')
uvd_out.write_uvh5(output_file, data_compression='bitshuffle', clobber=True)
print(output_file)
")
            echo librarian upload local-rtp ${diff_sum_file} ${jd}/${diff_sum_file}
            librarian upload local-rtp ${diff_sum_file} ${jd}/${diff_sum_file}
            echo "Finished uploading 32-channel summed diff file to Librarian at $(date)"
        fi
    done
fi
