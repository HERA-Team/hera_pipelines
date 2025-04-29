#! /bin/bash
set -e

# This loads a single baseline (all pols) for all times and calculates 2D DPSS filtered SNRs for finding RFI.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
FM_low_freq=${4}
FM_high_freq=${5}
filter_delay=${6}
auto_fr_spectrum_file=${7}
gauss_fit_buffer_cut=${8}
eigenval_cutoff=${9}
post_filter_delay_low_band=${10}
post_filter_delay_high_band=${11}
tv_chan_edges=${12}
tv_thresh=${13}
min_samp_frac=${14}

# path manipulation
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export RED_AVG_FILE=${SUM_FILE%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
export CORNER_TURN_MAP_YAML="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/corner_turn_map.yaml"

# other settings
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export FILTER_DELAY=${filter_delay}
export AUTO_FR_SPECTRUM_FILE=${auto_fr_spectrum_file}
export GAUSS_FIT_BUFFER_CUT=${gauss_fit_buffer_cut}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export POST_FILTER_DELAY_LOW_BAND=${post_filter_delay_low_band}
export POST_FILTER_DELAY_HIGH_BAND=${post_filter_delay_high_band}
export TV_CHAN_EDGES=${tv_chan_edges}
export TV_THRESH=${tv_thresh}
export MIN_SAMP_FRAC=${min_samp_frac}
export SNR_SUFFIX=".2Dfilt_SNR.uvh5"

# produce a string like "0_0" for a single baselinea and "0_0.0_1.0_2" for multiple baselines
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
nb_outfile="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/zen.${jd}.baseline.${antpairs_str}.sum.single_baseline_2D_filtered_SNRs.html"

# Execute jupyter notebook
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/single_baseline_2D_filtered_SNRs.ipynb
echo Finished running 2D DPSS filtering of single baseline SNRs notebook at $(date)

# check if "0_4" is in the antpairs_str, if so copy the notebook to the output repo
if [[ ".${antpairs_str}." == *".0_4."* ]]; then
    cp ${nb_outfile} ${nb_output_repo}/single_baseline_2D_filtered_SNRs/single_baseline_2D_filtered_SNRs_${jd}.ipynb
fi
