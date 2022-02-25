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
# 2 - path to configuration files
# 3 - path to simulation data files
fn="${1}"
config_path="${2}"
sim_dir="${3}"

jd_int=$(get_int_jd `basename ${fn}`)
config_file="${config_path}/${jd_int}.yaml"
paths="--sim_dir ${sim_dir} --config ${config_file}"

# Save bandpass only
bandpass_calfile=zen.${jd_int}.true_bandpass.calfits
echo python ${src_dir}/save_true_cal.py ${jd_int} ${bandpass_calfile} --include_bandpass ${paths} --clobber
python ${src_dir}/save_true_cal.py ${jd_int} ${bandpass_calfile} --include_bandpass ${paths} --clobber

# Save reflections only
reflections_calfile=zen.${jd_int}.true_reflections.calfits
echo python ${src_dir}/save_true_cal.py ${jd_int} ${reflections_calfile} --include_reflections ${paths} --clobber
python ${src_dir}/save_true_cal.py ${jd_int} ${reflections_calfile} --include_reflections ${paths} --clobber

# Save bandpass multiplied by reflections
final_gains_calfile=zen.${jd_int}.true_gains.calfits
echo python ${src_dir}/save_true_cal.py ${jd_int} ${final_gains_calfile} --include_bandpass --include_reflections ${paths} --clobber
python ${src_dir}/save_true_cal.py ${jd_int} ${final_gains_calfile} --include_bandpass --include_reflections ${paths} --clobber
