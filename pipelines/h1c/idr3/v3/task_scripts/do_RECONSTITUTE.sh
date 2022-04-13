#! /bin/bash
set -e

# This script takes full-day files of the form zen.*.final_calibrated.dpss_res.xtalk_filt_baseline_subgroup.uvh5 
# with only some baselines and rechunks them to have the same time structure as zen.*.final_calibrated.dpss_res.uvh5 files
# but with all baselines, renaming them zen.*.final_calibrated.dpss_res.xtalk_filt.uvh5.

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - template file name (template for time chunk to reconstitute).

fn="${1}"

# generate base uvh5 file
uvh5_fn=$(remove_pol $fn)
uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5

# get this dpss_res_file as a time template, all baseline subgroup files, and the outfilename
this_dpss_res_file=${uvh5_fn%.uvh5}.final_calibrated.dpss_res.uvh5
jd_int=$(get_int_jd `basename ${uvh5_fn}`)
all_baseline_subgroup_files=`echo zen.${jd_int}.*.final_calibrated.dpss_res.xtalk_filt_baseline_subgroup.uvh5`
this_outfile=${this_dpss_res_file%.uvh5}.xtalk_filt.uvh5

# build and run command
cmd="time_chunk_from_baseline_chunks_run.py ${this_dpss_res_file} \
                                            --baseline_chunk_files ${all_baseline_subgroup_files} \
                                            --outfilename ${this_outfile} \
                                            --clobber"
echo $cmd
$cmd
