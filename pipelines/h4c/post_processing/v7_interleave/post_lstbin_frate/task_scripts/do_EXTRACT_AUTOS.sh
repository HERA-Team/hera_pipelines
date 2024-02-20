#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# This script extracts the autocorrelations into a single waterfall file
label=${1}

sumdiff=("sum" "diff")

for sd in ${sumdiff[@]}
do
    flist=$(ls *${sd}.${label}.*chunked.uvh5)
    
    echo "python extract_autos_post_lstbin.py ${sd} ${label} --clobber --axis blt --flist ${flist}"
    
    python extract_autos_post_lstbin.py ${sd} ${label} --clobber --axis blt --flist ${flist}
done
