#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# This script extracts the autocorrelations into a single waterfall file
label=${1}
include_diffs=${2}

if [ "${include_diffs}" = "true" ] 
then
    sumdiff=("sum" "diff")
else
    sumdiff=("sum")
fi

for sd in ${sumdiff[@]}
do
    # *Sigh* bash
    # Use the return value of ls to see if it runs OK (don't want to pass an empty list for example)
    # Redirect the output to die in /dev/null/ so it doesn't crowd the log
    # Exit if there is an error.
    if ls *${sd}.${label}.*chunked.uvh5 1> /dev/null 
    then
        flist=$(ls *${sd}.${label}.*chunked.uvh5)
    else
        echo "Error when calling ls on ${sd} files with label ${label}. Probably could not find files. Check error log. Exiting."
        exit 1
    fi
    
    echo "python extract_autos_post_lstbin.py ${sd} ${label} --clobber --axis blt --flist ${flist}"
    
    python extract_autos_post_lstbin.py ${sd} ${label} --clobber --axis blt --flist ${flist}
done
