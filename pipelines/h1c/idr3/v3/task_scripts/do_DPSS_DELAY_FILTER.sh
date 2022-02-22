#! /bin/bash
set -e

# This script performs a delay filter with DPSS.

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename of base file ending in .xx.HH.uv
# 2 - tolerance threshold for foreground subtraction
# 3 - factor that sets the edge of the wedge. 1.0 means the horizon
# 4 - additional supra-hroizon standoff/buffer in ns
# 5 - minimum delay below which to filter, regardless of baseline length
# 6 - directory for caching DPSS matrices
fn="${1}"
tol="${2}"
horizon="${3}"
standoff="${4}"
min_dly="${5}"
cache_dir="${6}"

# if cache directory does not exist, make it
if [ ! -d "${cache_dir}" ]; then
  mkdir ${cache_dir}
fi

# get input and output files
infile=${fn%.xx.HH.uv}.sum.final_calibrated.uvh5
res_file=${fn%.xx.HH.uv}.sum.final_calibrated.dpss_res.uvh5
filled_file=${fn%.xx.HH.uv}.sum.final_calibrated.dpss_filled.uvh5
mdl_file=${fn%.xx.HH.uv}.sum.final_calibrated.dpss_mdl.uvh5  # TODO: elimate this?

# build and run command
cmd="delay_filter_run.py ${infile} \
                         --res_outfilename ${res_file} \
                         --filled_outfilename ${filled_file} \
                         --CLEAN_outfilename ${mdl_file} \
                         --tol ${tol} \
                         --standoff ${standoff} \
                         --horizon ${horizon} \
                         --min_dly ${min_dly} \
                         --mode dpss_leastsq \
                         --cache_dir ${cache_dir} \
                         --write_cache \
                         --read_cache \
                         --clobber \
                         --verbose"
echo $cmd
$cmd
