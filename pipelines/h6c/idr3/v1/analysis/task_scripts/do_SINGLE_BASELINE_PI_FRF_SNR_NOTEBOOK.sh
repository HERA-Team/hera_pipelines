#! /bin/bash
set -e

# This loads single baselines (all pols) for all times, forms pseudo-Stokes pI,
# and computes delay-filtered, fringe-rate-filtered SNR waterfalls.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
FM_low_freq=${4}
FM_high_freq=${5}
filter_delay=${6}
eigenval_cutoff=${7}
fr_spectra_file=${8}
auto_fr_spectrum_file=${9}
xtalk_fr=${10}
fr_quantile_low=${11}
fr_quantile_high=${12}
min_samp_frac=${13}

# path manipulation
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export RED_AVG_FILE=${SUM_FILE%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
export CORNER_TURN_MAP_YAML="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/corner_turn_map.yaml"

# other settings
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export FILTER_DELAY=${filter_delay}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export FR_SPECTRA_FILE=${fr_spectra_file}
export AUTO_FR_SPECTRUM_FILE=${auto_fr_spectrum_file}
export XTALK_FR=${xtalk_fr}
export FR_QUANTILE_LOW=${fr_quantile_low}
export FR_QUANTILE_HIGH=${fr_quantile_high}
export MIN_SAMP_FRAC=${min_samp_frac}
export FRF_SNR_SUFFIX=".pI_FRF_SNR.uvh5"
export SAVE_DLY_SNR="True"
export DLY_SNR_SUFFIX=".pI_DLYFILT_SNR.uvh5"
export SAVE_FRF_SNR="True"

# produce a string like "0_0" for a single baseline and "0_0.0_1.0_2" for multiple baselines
antpairs_str=$(python -c "
import yaml
with open('${CORNER_TURN_MAP_YAML}', 'r') as file:
    corner_turn_map = yaml.unsafe_load(file)

antpairs = corner_turn_map['files_to_antpairs_map']['${RED_AVG_FILE}']
ubl_keys = [corner_turn_map['antpairs_to_ubl_keys_map'][ap] for ap in antpairs]
ubl_keys = [k for k in ubl_keys if k[0] != k[1]]  # skip autos
if len(ubl_keys) > 0:
    print('.'.join(['_'.join(str(ant) for ant in ap) for ap in ubl_keys]))
else:
    print('none')
")

if [ "$antpairs_str" = "none" ]; then
    echo "No antpairs match this input file. Exiting..."
    exit 0
fi
jd=$(get_int_jd ${fn})
nb_outfile="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/zen.${jd}.baseline.${antpairs_str}.sum.single_baseline_pI_FRF_SNR.html"

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/single_baseline_pI_FRF_SNR.ipynb
echo Finished running single baseline pI FRF SNR notebook at $(date)

# check if "0_4" is in the antpairs_str, if so copy the notebook to the output repo
if [[ ".${antpairs_str}." == *".0_4."* ]]; then
    cp ${nb_outfile} ${nb_output_repo}/single_baseline_pI_FRF_SNR/single_baseline_pI_FRF_SNR_${jd}.html
    python ${src_dir}/build_notebook_index.py ${nb_output_repo}/single_baseline_pI_FRF_SNR
fi
