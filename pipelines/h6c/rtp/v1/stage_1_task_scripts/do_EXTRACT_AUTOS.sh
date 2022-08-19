#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_autos: boolean trigger for this step
fn="${1}"
upload_to_librarian="${2}"
librarian_autos="${3}"

# get outfilename, removing extension and appending .autos.uvh5
autos_file=`echo ${fn%.sum.uvh5}.sum.autos.uvh5`

echo extract_autos.py ${fn} ${autos_file} --clobber
extract_autos.py ${fn} ${autos_file} --clobber
echo Finished extracting autos from sum data at $(date)

# now do the same for the diffs
diff_file=`echo ${fn%.sum.uvh5}.diff.uvh5`
diff_autos_file=`echo ${fn%.sum.uvh5}.diff.autos.uvh5`

echo extract_autos.py ${diff_file} ${diff_autos_file} --clobber
extract_autos.py ${diff_file} ${diff_autos_file} --clobber
echo Finished extracting autos from diff data at $(date)

if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_autos}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn})

        echo librarian upload local-rtp ${autos_file} ${jd}/${autos_file}
        librarian upload local-rtp ${autos_file} ${jd}/${autos_file}
        echo Finished uploading sum autos to Librarian at $(date)

        echo librarian upload local-rtp ${diff_autos_file} ${jd}/${diff_autos_file}
        librarian upload local-rtp ${diff_autos_file} ${jd}/${diff_autos_file}
        echo Finished uploading diff autos to Librarian at $(date)
    fi
fi
