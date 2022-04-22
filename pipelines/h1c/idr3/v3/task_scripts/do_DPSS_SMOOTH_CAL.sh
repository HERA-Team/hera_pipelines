#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
### cal smoothing parameters - see hera_cal.smooth_cal for details
# 2 - freq_scale
# 3 - time_scale
# 4 - eigenval_cutoff
# 5 - freq_threshold
# 6 - time_threshold
# 7 - ant_threshold
# 8 - lst_blacklists
fn="${1}"
freq_scale="${2}"
time_scale="${3}"
eigenval_cutoff="${4}"
freq_threshold="${5}"
time_threshold="${6}"
ant_threshold="${7}"
lst_blacklists="${8}"

# get list of all calfiles for a day
jd=$(get_jd $fn)
int_jd=${jd:0:7}
calfiles=`echo zen.${int_jd}.*.flagged_abs.calfits`

cmd="smooth_cal_run.py ${calfiles} \
                       --infile_replace .flagged_abs. \
                       --outfile_replace .smooth_abs. \
                       --pick_refant \
                       --freq_scale ${freq_scale} \
                       --time_scale ${time_scale} \
                       --method DPSS \
                       --eigenval_cutoff ${eigenval_cutoff} \
                       --freq_threshold ${freq_threshold} \
                       --time_threshold ${time_threshold} \
                       --ant_threshold ${ant_threshold} \
                       --lst_blacklists ${lst_blacklists} \
                       --clobber \
                       --verbose"
echo $cmd
$cmd
