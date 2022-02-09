#! /bin/bash
set -e

# This script runs redundant-baseline calibration on antennas believed to be good a priori

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - ant_z_thresh: Threshold of modified z-score for chi^2 per antenna above which antennas are thrown away and calibration is re-run iteratively.
# 3 - solar_horizon: When the Sun is above this altitude in degrees, calibration is skipped and the integrations are flagged.
# 4 - flag_nchan_low: integer number of channels at the low frequency end of the band to always flag (default 0)
# 5 - flag_nchan_high: integer number of channels at the high frequency end of the band to always flag (default 0)
# 6 - oc_maxiter: integer maximum number of iterations of omnical allowed
# 7 - nInt_to_load: number of integrations to load and calibrate simultaneously. Lower numbers save memory, but incur a CPU overhead.
# 8 - min_bl_cut: cut redundant groups with average baseline lengths shorter than this length in meters
# 9 - max_bl_cut: cut redundant groups with average baseline lengths longer than this length in meters
# 10 - fc_min_vis_per_ant: minimum number of equations in firstcal that each antenna needs to be involved in
# 11 - max_dims: maximum allowed tip/tilt phase degeneracies of redcal. 2 is classically redundant.
# 12 - check_every: ompute omnical convergence every Nth iteration
# 13 - check_after: start computing omnical convergence only after N iterations

fn="${1}"
ant_z_thresh="${2}"
solar_horizon="${3}"
flag_nchan_low="${4}"
flag_nchan_high="${5}"
oc_maxiter="${6}"
nInt_to_load="${7}"
min_bl_cut="${8}"
max_bl_cut="${9}"
fc_min_vis_per_ant="${10}"
max_dims="${11}"
check_every="${12}"
check_after="${13}"

# make sure input file is correct uvh5 file
uvh5_fn=$(remove_pol $fn)
uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software

# get a priori ex_ants yaml file
jd_int=$(get_int_jd `basename ${uvh5_fn}`)
ex_ants_yaml=`echo "${path_to_a_priori_flags}/${jd_int}.yaml"`

# run redcal
cmd="redcal_run.py ${uvh5_fn} \
                   --ant_z_thresh ${ant_z_thresh} \
                   --solar_horizon ${solar_horizon} \
                   --oc_maxiter ${oc_maxiter} \
                   --flag_nchan_low ${flag_nchan_low} \
                   --flag_nchan_high ${flag_nchan_high} \
                   --nInt_to_load ${nInt_to_load} \
                   --min_bl_cut ${min_bl_cut} \
                   --max_bl_cut ${max_bl_cut} \
                   --max_dims ${max_dims} \
                   --fc_min_vis_per_ant ${fc_min_vis_per_ant} \
                   --check_every ${check_every} \
                   --check_after ${check_after} \
                   --clobber \
                   --verbose"
echo $cmd
$cmd