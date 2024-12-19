#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

echo "reading in inputs..."

reffile="${1}" # reference file used to mock up the simulated data (has form *sum.uvh5)
sky_cmp="${2}" # simulation type (e.g. diffuse, eor, point_src) must match name in file (e.g. zen.LST.123333.<sky_cmp>.uvh5)
#path= currently hardcoded instead "${3}"   path to data folders (e.g. <path>/2459122/)

jd=$(get_int_jd ${reffile})
echo "jd is ${jd}"
ref_path=/lustre/aoc/projects/hera/h6c-analysis/IDR2/${jd}/${reffile}
outdir=/lustre/aoc/projects/hera/Validation/H6C_IDR/${jd}/
#outdir=/lustre/aoc/projects/hera/Validation/H4C/IDR2/mocked_data/${sky_cmp}/${jd}/
#mkdir -p ${outdir} # the -p only makes dir it not existing

config_file=/lustre/aoc/projects/hera/Validation/H6C_IDR2/src/hera_pipelines/pipelines/validation/h6c/configs/${jd}.yaml

echo "mocking up data for ${sky_cmp} sims..."
echo "==============================================="
echo "assuming a Julian date of: ${jd}"
echo "using config file: ${config_file}"


# for f in "${refdir}"*;
# do
# reffile=$(basename ${f});
# echo ${name};
echo "using ${reffile}";
echo "python /lustre/aoc/projects/hera/Validation/H6C_IDR2/src/hera_pipelines/pipelines/validation/h6c/analysis/task_scripts/mock_data.py ${ref_path} ${sky_cmp} --config $config_file --sim_dir /lustre/aoc/projects/hera/Validation/H4C/IDR2/chunked_data/ -o ${outdir} --lst_wrap 3.1419561 --input_is_compressed --inflate --clobber"
python /lustre/aoc/projects/hera/Validation/H6C_IDR2/src/hera_pipelines/pipelines/validation/h6c/analysis/task_scripts/mock_data.py ${ref_path} ${sky_cmp} --config $config_file --sim_dir /lustre/aoc/projects/hera/Validation/H4C/IDR2/chunked_data/ -o ${outdir} --lst_wrap 3.1419561 --input_is_compressed --inflate --clobber
echo "saved file to ${outdir}"

