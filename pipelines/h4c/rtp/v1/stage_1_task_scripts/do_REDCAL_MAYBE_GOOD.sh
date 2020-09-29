#! /bin/bash
set -e

# This script runs redundant-baseline calibration on antennas that, a priori, might be good

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
# 10 - ant_metrics_extension: file extension to replace .uvh5 with to get maybe good ant_metrics files
# 11 - max_dims: maximum allowed tip/tilt phase degeneracies of redcal. 2 is classically redundant.
# 12 - upload_to_librarian: global boolean trigger
# 13 - librarian_redcal_maybe_good: boolean trigger for this step
fn="${1}"
ant_z_thresh="${2}"
solar_horizon="${3}"
flag_nchan_low="${4}"
flag_nchan_high="${5}"
oc_maxiter="${6}"
nInt_to_load="${7}"
min_bl_cut="${8}"
max_bl_cut="${9}"
ant_metrics_extension="${10}"
max_dims="${11}"
upload_to_librarian="${12}"
librarian_redcal_maybe_good="${13}"

# get ant_metrics file, removing extension and appending ant_metrics_extension
metrics_f=`echo ${fn%.uvh5}${ant_metrics_extension}`

# run redcal
echo redcal_run.py ${fn} --ant_z_thresh ${ant_z_thresh} --solar_horizon ${solar_horizon} --oc_maxiter ${oc_maxiter} \
    --firstcal_ext .maybe_good.first.calfits --omnical_ext .maybe_good.omni.calfits \
    --omnivis_ext .maybe_good.omni_vis.uvh5 --meta_ext .maybe_good.redcal_meta.hdf5 \
    --flag_nchan_low ${flag_nchan_low} --flag_nchan_high ${flag_nchan_high} --nInt_to_load ${nInt_to_load} \
    --min_bl_cut ${min_bl_cut} --max_bl_cut ${max_bl_cut} --ant_metrics_file ${metrics_f} \
    --max_dims ${max_dims} --clobber --verbose
redcal_run.py ${fn} --ant_z_thresh ${ant_z_thresh} --solar_horizon ${solar_horizon} --oc_maxiter ${oc_maxiter} \
    --firstcal_ext .maybe_good.first.calfits --omnical_ext .maybe_good.omni.calfits \
    --omnivis_ext .maybe_good.omni_vis.uvh5 --meta_ext .maybe_good.redcal_meta.hdf5 \
    --flag_nchan_low ${flag_nchan_low} --flag_nchan_high ${flag_nchan_high} --nInt_to_load ${nInt_to_load} \
    --min_bl_cut ${min_bl_cut} --max_bl_cut ${max_bl_cut} --ant_metrics_file ${metrics_f} \
    --max_dims ${max_dims} --clobber --verbose

# add data products to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_redcal_maybe_good}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn})

        # upload files to librarian
        declare -a exts=(
            ".maybe_good.first.calfits"
            ".maybe_good.omni.calfits"
            ".maybe_good.omni_vis.uvh5"
            ".maybe_good.redcal_meta.hdf5"
        )
        for ext in ${exts[@]}; do
            fn_out=`echo ${fn%.uvh5}${ext}`
            echo librarian upload local-rtp ${fn_out} ${jd}/${fn_out}
            librarian upload local-rtp ${fn_out} ${jd}/${fn_out}
        done
    fi
fi
