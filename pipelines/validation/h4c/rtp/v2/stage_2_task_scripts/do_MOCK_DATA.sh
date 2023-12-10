#!/bin/bash
set -e

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# source bash profile
source /users/lmcbride/.bashrc
conda activate h4c_validation

reffile="${1}" # reference file used to mock up the simulated data (has form *sum.uvh5)
sim_type="${2}" # simulation type (e.g. diffuse, eor, point_src) must match name in file (e.g. zen.LST.123333.<sim_type>.uvh5)
#path= currently hardcoded instead "${3}"   path to data folders (e.g. <path>/2459122/)

jd=$(get_int_jd ${fn})
ref_path=/lustre/aoc/projects/hera/Validation/H4C/IDR2/${jd}/${reffile}
outdir=/lustre/aoc/projects/hera/Validation/H4C/IDR2/${jd}/
#outdir=/lustre/aoc/projects/hera/Validation/H4C/IDR2/mocked_data/${sim_type}/${jd}/
#mkdir -p ${outdir} # the -p only makes dir it not existing

config_file="/lustre/aoc/projects/hera/Validation/H4C/IDR2/configs/${jd}.yaml"

echo "mocking up data for ${sim_type} sims..."
echo "==============================================="
echo "assuming a Julian date of: ${jd}"
echo "using config file: ${config_file}"


# for f in "${refdir}"*;
# do
# reffile=$(basename ${f});
# echo ${name};
echo "using ${reffile}";
python /users/heramgr/hera_software/hera_pipelines/pipelines/validation/h4c/rtp/v2/stage_2_task_scripts/mock_data.py ${ref_path} ${simtype} --config $config_file --sim_dir /lustre/aoc/projects/hera/Validation/H4C/IDR2/chunked_data/ -o ${outdir} --lst_wrap 3.1419561 ----input_is_compressed --inflate
echo "saved file to ${outdir}"

done
