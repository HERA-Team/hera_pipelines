#! /bin/bash
set -e

# This function uploads all redundantly averaged visibility files 
# (after post-processing) to the Librarian.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_redcal: boolean trigger for this step
fn="${1}"
upload_to_librarian="${2}"
librarian_red_avg_vis="${3}"
save_diff_red_avg="${4}"
save_abs_cal_red_avg="${5}"
save_dly_filt_red_avg="${6}"

bn=`basename ${fn}`
jd=$(get_int_jd ${fn})

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_red_avg_vis}" == "True" ]; then

        # Compress all red_avg files per output type into one with a JD corresponding to $fn
        declare -a exts=(
            ".reds_used.p"
            ".sum.smooth_calibrated.avg_abs_all.uvh5"
            ".sum.smooth_calibrated.avg_abs_auto.uvh5"
            ".sum.smooth_calibrated.avg_abs_cross.uvh5"
            ".sum.smooth_calibrated.red_avg.uvh5"
        )
        if [ "${save_dly_filt_red_avg}" == "True" ]; then
            exts+=(".sum.smooth_calibrated.red_avg.dly_filt.uvh5")
        fi

        if [ "${save_diff_red_avg}" == "True" ]; then
            exts+=(".diff.smooth_calibrated.red_avg.uvh5")
        fi

        if [ "${save_diff_red_avg}" == "True" ] && [ "${save_dly_filt_red_avg}" == "True" ]; then
            exts+=(".diff.smooth_calibrated.red_avg.dly_filt.uvh5")
        fi

        if [ "${save_abs_cal_red_avg}" == "True" ]; then
            exts+=(".sum.abs_calibrated.red_avg.uvh5")
            
            if [ "${save_dly_filt_red_avg}" == "True" ]; then
                exts+=(".sum.abs_calibrated.red_avg.dly_filt.uvh5")
            fi

            if [ "${save_diff_red_avg}" == "True" ]; then
                exts+=(".diff.abs_calibrated.red_avg.uvh5")
            fi

            if [ "${save_diff_red_avg}" == "True" ] && [ "${save_dly_filt_red_avg}" == "True" ]; then
                exts+=(".diff.abs_calibrated.red_avg.dly_filt.uvh5")
            fi
        fi

        for ext in ${exts[@]}; do
            compressed_file=`echo ${fn%.uvh5}${ext}.tar.gz`
            echo tar czfv ${compressed_file} zen.${jd}*${ext}
            tar czfv ${compressed_file} zen.${jd}*${ext}

            # Upload gzipped file to the librarian
            librarian_file=`basename ${compressed_file}`
            echo librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
            librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
            echo Finished uploading ${compressed_file} to the Librarian at $(date)
        done
    fi
fi
echo Finished running librarian red_avg_vis at $(date)
