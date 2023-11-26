#!/bin/bash
set -e

# source bash profile
source /users/lmcbride/.bashrc
conda activate h4c_validation

jd="${1}" # current JD day that is being mocked up (e.g. 2459122 as above)
sim_type="${2}" # simulation type (e.g. diffuse, eor, point_src) must match name in file (e.g. zen.LST.123333.<sim_type>.uvh5)
#path= currently hardcoded instead "${3}"   path to data folders (e.g. <path>/2459122/)

refdir=/lustre/aoc/projects/hera/Validation/H4C/IDR2/${jd}/
outdir=/lustre/aoc/projects/hera/Validation/H4C/IDR2/mocked_data/${sim_type}/${jd}/
mkdir -p ${outdir} # the -p only makes dir it not existing

config_file="/lustre/aoc/projects/hera/Validation/H4C/IDR2/configs/${jd}.yaml"

echo "mocking up data for ${sim_type} sims..."
echo "==============================================="
echo "assuming a Julian date of: ${jd}"
echo "using config file: ${config_file}"


for f in "${refdir}"*;
do
reffile=$(basename ${f});
# echo ${name};
echo "ref file is ${reffile}";
#python mock_data.py ${reffile} ${simtype} --config $config_file --sim_dir /lustre/aoc/projects/hera/Validation/H4C/IDR2/chunked_data/ -o ${outdir} --lst_wrap 3.1419561 ----input_is_compressed --inflate
echo "saved file ${reffile} to ${outdir}"

done
