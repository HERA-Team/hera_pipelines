#! /bin/bash
set -e

# This function perform a FRF centered on FR=0 to remove cross-talk in H1C. Operates on DPSS delay-filtered residuals.

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - base filename
# 2 - tolerance (level to subtract cross-talk to)
# 3 - constant term in linear equation for maximum fringe rate half-width of the filter
# 4 - linear term in linear equation for maximum fringe rate  half-width of the filter
# 5 - overall maximum fringe rate half-width to filter to, regardless of the linear equation above
# 6 - overall minimum fringe rate half-width to filter to, regardless of the linear equation above
# 7 - directory for caching DPSS matrices
# 8 - list of lsts to assign blacklist_wgt weight, input as a space-separated list of dash-separted pairs
# 9 - blacklist_wgt (see above)
fn="${1}"
tol="${2}"
max_frate_const_term="${3}"
max_frate_linear_term="${4}"
min_frate_half_width="${5}"
max_frate_half_width="${6}"
cache_dir="${7}"
lst_blacklists="${8}"
blacklist_wgt="${9}"

# if cache directory does not exist, make it
if [ ! -d ${cache_dir} ]; then
    mkdir ${cache_dir}
fi

# generate base uvh5 file
uvh5_fn=$(remove_pol $fn)
uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5

# get this and all dpss_res files
this_dpss_res_file=${uvh5_fn%.uvh5}.final_calibrated.dpss_res.uvh5
jd_int=$(get_int_jd `basename ${uvh5_fn}`)
all_dpss_res_files=`echo zen.${jd_int}.*.final_calibrated.dpss_res.uvh5`
this_outfile=${this_dpss_res_file%.uvh5}.xtalk_filt_baseline_subgroup.uvh5

# build and run command
cmd="tophat_frfilter_run.py ${all_dpss_res_files} \
                            --cornerturnfile ${this_dpss_res_file} \
                            --res_outfilename ${this_outfile} \
                            --tol ${tol} \
                            --case max_frate_coeffs \
                            --max_frate_coeffs ${max_frate_linear_term} ${max_frate_const_term} \
                            --min_frate_half_width ${min_frate_half_width} \
                            --max_frate_half_width ${max_frate_half_width} \
                            --cache_dir ${cache_dir} \
                            --write_cache \
                            --read_cache \
                            --lst_blacklists ${lst_blacklists} \
                            --blacklist_wgt ${blacklist_wgt} \
                            --mode dpss_leastsq \
                            --max_contiguous_edge_flags 10000 \
                            --dont_skip_contiguous_flags \
                            --dont_flag_model_rms_outliers \
                            --skip_autos \
                            --clobber \
                            --verbose"
echo $cmd
$cmd
