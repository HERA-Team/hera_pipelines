#! /bin/bash
set -e

# This script performs CLEAN-based inpainting of smooth_calibrated autocorrelations.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2-13 - See delay_filter_run.py -h
fn="${1}"
horizon="${2}"
standoff="${3}"
min_dly="${4}"
gain="${5}"
maxiter="${6}"
window="${7}"
alpha="${8}"
edgecut_low="${9}"
edgecut_hi="${10}"
tol="${11}"
skip_wgt="${12}"
zeropad="${13}"

# make sure input file is correct uvh5 file
uvh5_fn=$(remove_pol $fn)
uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software

# get derivative file names
autos_file=`echo ${uvh5_fn%.*}.autos.uvh5`
smooth_abs_calfile=`echo ${uvh5_fn%.uvh5}.smooth_abs.calfits`
filled_outfile=`echo ${autos_file%.uvh5}.inpainted.uvh5`

# build and execute command
cmd="delay_filter_run.py ${autos_file} \
                         --calfilelist ${smooth_abs_calfile} \
                         --filled_outfilename ${filled_outfile} \
                         --mode clean \
                         --dont_skip_contiguous_flags
                         --dont_skip_flagged_edges
                         --dont_flag_model_rms_outliers
                         --horizon ${horizon} \
                         --standoff ${standoff} \
                         --min_dly ${min_dly} \
                         --gain ${gain} \
                         --maxiter ${maxiter} \
                         --window ${window} \
                         --alpha ${alpha} \
                         --edgecut_low ${edgecut_low} \
                         --edgecut_hi ${edgecut_hi} \
                         --tol ${tol} \
                         --skip_wgt ${skip_wgt} \
                         --zeropad ${zeropad} \
                         --clobber \
                         --verbose"
echo $cmd
$cmd
