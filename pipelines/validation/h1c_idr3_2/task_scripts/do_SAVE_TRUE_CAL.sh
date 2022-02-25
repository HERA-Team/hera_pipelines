#! /bin/bash
set -e

# This script generates and saves the true daily calibration solution,
# which is time-independent, as a single integration file labeled by the JD.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
fn="${1}"

jd_int=$(get_int_jd `basename ${fn}`)

# Save bandpass only
bandpass_calfile=zen.${jd_int}.true_bandpass.calfits
echo python ${src_dir}/save_true_cal.py ${jd_int} ${bandpass_calfile} --include_bandpass --clobber
python ${src_dir}/save_true_cal.py ${jd_int} ${bandpass_calfile} --include_bandpass --clobber

# Save bandpass multiplied by reflections
final_gains_calfile=zen.${jd_int}.true_gains_with_refl.calfits
echo python ${src_dir}/save_true_cal.py ${jd_int} ${final_gains_calfile} --include_bandpass --include_reflections --clobber
python ${src_dir}/save_true_cal.py ${jd_int} ${final_gains_calfile} --include_bandpass --include_reflections --clobber
