#! /bin/bash
set -e

# This script generates a notebook that processes a single-baseline file, typically redundantly-averaged and
# LST-binned, through to power spectra

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2+ - various settings
fn=${1}
nb_template_dir=${2}
band_str=${3}
already_inpainted=${4}
perform_inpaint=${5}
inpaint_min_dly=${6}
inpaint_horizon=${7}
inpaint_standoff=${8}
inpaint_eigenval_cutoff=${9}
perform_dly_filt=${10}
dly_filt_min_dly=${11}
dly_filt_horizon=${12}
dly_filt_standoff=${13}
dly_filt_eigenval_cutoff=${14}
use_band_avg_nsamples=${15}
fm_cut_freq=${16}
pixel_flag_cut=${17}
channel_flag_cut=${18}
integration_flag_cut=${19}
ninterleave=${20}
xtalk_fr=${21}
fr_spectra_file=${22}
fr_quantile_low=${23}
fr_quantile_high=${24}
fr_eigenval_cutoff=${25}
target_averaging_time=${26}
use_corr_matrix=${27}
corr_matrix_freq_decimation=${28}
corr_matrix_notch_cutoff=${29}
efield_healpix_beam_file=${30}
taper=${31}
include_interleave_auto_ps=${32}
store_window_functions=${33}

# Export variables used by the notebook
full_file_path="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
echo "Performing single baseline postprocessing and power spectrum estimation on ${full_file_path}"
export SINGLE_BL_FILE=${full_file_path}
export OUT_PSPEC_FILE=${full_file_path%.uvh5}.pspec.h5
export BAND_STR=${band_str}
export ALREADY_INPAINTED=${already_inpainted}
export PERFORM_INPAINT=${perform_inpaint}
export INPAINT_MIN_DLY=${inpaint_min_dly}
export INPAINT_HORIZON=${inpaint_horizon}
export INPAINT_STANDOFF=${inpaint_standoff}
export INPAINT_EIGENVAL_CUTOFF=${inpaint_eigenval_cutoff}
export PERFORM_DLY_FILT=${perform_dly_filt}
export DLY_FILT_MIN_DLY=${dly_filt_min_dly}
export DLY_FILT_HORIZON=${dly_filt_horizon}
export DLY_FILT_STANDOFF=${dly_filt_standoff}
export DLY_FILT_EIGENVAL_CUTOFF=${dly_filt_eigenval_cutoff}
export USE_BAND_AVG_NSAMPLES=${use_band_avg_nsamples}
export FM_CUT_FREQ=${fm_cut_freq}
export PIXEL_FLAG_CUT=${pixel_flag_cut}
export CHANNEL_FLAG_CUT=${channel_flag_cut}
export INTEGRATION_FLAG_CUT=${integration_flag_cut}
export NINTERLEAVE=${ninterleave}
export XTALK_FR=${xtalk_fr}
export FR_SPECTRA_FILE=${fr_spectra_file}
export FR_QUANTILE_LOW=${fr_quantile_low}
export FR_QUANTILE_HIGH=${fr_quantile_high}
export FR_EIGENVAL_CUTOFF=${fr_eigenval_cutoff}
export TARGET_AVERAGING_TIME=${target_averaging_time}
export USE_CORR_MATRIX=${use_corr_matrix}
export CORR_MATRIX_FREQ_DECIMATION=${corr_matrix_freq_decimation}
export CORR_MATRIX_NOTCH_CUTOFF=${corr_matrix_notch_cutoff}
export EFIELD_HEALPIX_BEAM_FILE=${efield_healpix_beam_file}
export TAPER=${taper}
export INCLUDE_INTERLEAVE_AUTO_PS=${include_interleave_auto_ps}
export STORE_WINDOW_FUNCTIONS=${store_window_functions}

# check if file is not just autocorrelaitons and that neither polarization is fully flagged
if python ${src_dir}/check_single_bl_file.py ${full_file_path} --skip_autos --skip_outriggers; then
    # Execute jupyter notebook
    nb_outfile=${full_file_path%.uvh5}.single_baseline_postprocessing_and_pspec.html
    jupyter nbconvert --output=${nb_outfile} \
    --to html \
    --ExecutePreprocessor.allow_errors=False \
    --ExecutePreprocessor.timeout=-1 \
    --execute ${nb_template_dir}/single_baseline_postprocessing_and_pspec.ipynb
    echo Finished running single baseline postprocessing and power spectrum estimation notebook for ${fn} at $(date) and writing results to ${nb_outfile}

    # Check to see that output file was correctly produced
    if [ -f "${fn%.uvh5}.pspec.h5" ]; then
        echo Resulting $f found.
    else
        echo $f not produced.
        exit 1
    fi
else
    echo "File ${full_file_path} is either just autocorrelations or has a fully flagged polarization. Skipping the power spectrum notebook."
fi
