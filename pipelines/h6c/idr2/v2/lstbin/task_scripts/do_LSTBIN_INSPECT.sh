#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - The LST-bin case (eg. "redavg-smoothcal"). Generally provided as "basename" from mf.
# 2 - The path to LST-bin outputs (i.e. a directory containing directories of "cases"
# 3 - The directory in which to save the output notebook
# 4 - The conda kernel to use.

# get positional arguments
case=${1}
lstbinpath=${2}
nbpath=${3}
kernel=${4}

pth="${lstbinpath}/${case}"

# Check if this case is split into flagged/inpaint sub-cases
flagged="${pth}/flagged"
echo "FLAGGED: $flagged"
if [ -d "$flagged" ]; then
    # We should have both flagged/inpaint cases
    modes=("flagged" "inpaint")
    echo "does exist!"
else
    echo "does not exist"
    modes=("flagged")
fi

for mode in ${modes[@]}; do 
    outname="${case}.${mode}.lstbin-inspect"
    
    cmd="hnote run --output-dir ${nbpath} -k ${kernel} lstbin-inspect -o ${outname} --lstbin-path=${pth} --flag-treatment=${mode}"

   echo $cmd
   eval $cmd

   if [ -f "${nbpath}/${outname}.html" ]
   then
       echo "Done!"
   else
       echo "The job failed!"
       exit 1
   fi
done

