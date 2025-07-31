#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
fn="${1}"

# get outfilename, removing extension and appending .autos.uvh5
autos_file=`echo ${fn%.sum.uvh5}.sum.autos.uvh5`

if [ -f "$autos_file" ]; then
    echo ${autos_file} already exists... skipping extraction.
else
    echo ${src_dir}/robust_extract_autos.py ${fn} ${autos_file} --clobber
    ${src_dir}/robust_extract_autos.py ${fn} ${autos_file} --clobber
    echo Finished extracting autos from sum data at $(date)
fi

# now do the same for the diffs
diff_file=`echo ${fn%.sum.uvh5}.diff.uvh5`
diff_autos_file=`echo ${fn%.sum.uvh5}.diff.autos.uvh5`

if [ -f "$diff_autos_file" ]; then
    echo ${diff_autos_file} already exists... skipping extraction.
else
    if [ -f "$diff_file" ]; then
        echo ${src_dir}/robust_extract_autos.py ${diff_file} ${diff_autos_file} --clobber
        ${src_dir}/robust_extract_autos.py ${diff_file} ${diff_autos_file} --clobber
        echo Finished extracting autos from diff data at $(date)
    else
        echo ${diff_file} does not exist... skipping extraction.
    fi
fi

# now delete .dat files, since we've already shown that they are readable
sum_dat_file=`echo ${fn%.sum.uvh5}.sum.dat`
if [ -f "$sum_dat_file" ]; then
    if [ -f "$fn" ]; then
        echo Removing ${sum_dat_file}
        rm -rf ${sum_dat_file}
    fi
fi
diff_dat_file=`echo ${fn%.sum.uvh5}.diff.dat`
if [ -f "$diff_dat_file" ]; then
    if [ -f "$diff_file" ]; then
        echo Removing ${diff_dat_file}
        rm -rf ${diff_dat_file}
    fi
fi
