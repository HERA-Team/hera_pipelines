#! /bin/bash
set -e

# This script performs a low-pass filter of the abscal model using CLEAN

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2-12 - See delay_filter_run.py -h
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

# create input file
infile=`basename $fn`
infile=${infile::17}.abscal_model.uvh5 # pick out zen.???????.?????

# create outfile
outfile=${infile%.uvh5}.smoothed.uvh5

# build and execute command
cmd="delay_filter_run.py ${infile} \
                         --CLEAN_outfilename ${outfile} \
                         --mode clean \
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
                         --clobber \
                         --verbose"
echo $cmd
$cmd
