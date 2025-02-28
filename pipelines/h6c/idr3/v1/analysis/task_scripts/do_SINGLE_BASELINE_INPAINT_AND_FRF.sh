#! /bin/bash
set -e

# This loads a single baseline (all pols) for all times on a single JD and writes it as its own file.

src_dir="$(dirname "$0")"

fn=${1}
# nb_template_dir=${2}
# nb_output_repo=${3}
# FM_low_freq=${4}
# FM_high_freq=${5}
# filter_delay=${6}
# min_frate_half_width=${7}
# eigenval_cutoff=${8}

# # path manipulation
# export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
# export RED_AVG_FILE=${SUM_FILE%.sum.uvh5}.sum.smooth_calibrated.red_avg.uvh5
# export CORNER_TURN_MAP_YAML="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/corner_turn_map.yaml"

# # other settings
# export FM_LOW_FREQ=${FM_low_freq}
# export FM_HIGH_FREQ=${FM_high_freq}
# export FILTER_DELAY=${filter_delay}
# export MIN_FRATE_HALF_WIDTH=${min_frate_half_width}
# export EIGENVAL_CUTOFF=${eigenval_cutoff}
# export SNR_SUFFIX=".2Dfilt_SNR.uvh5"

# # produce a string like "0_0" for a single baselinea and "0_0.0_1.0_2" for multiple baselines
# antpairs_str=$(python -c "
# import yaml
# with open('${CORNER_TURN_MAP_YAML}', 'r') as file:
#     corner_turn_map = yaml.unsafe_load(file)

# antpairs = corner_turn_map['files_to_antpairs_map']['${RED_AVG_FILE}']
# ubl_keys = [corner_turn_map['antpairs_to_ubl_keys_map'][ap] for ap in antpairs]
# ubl_keys = [k for k in ubl_keys if k[0] != k[1]]  # skip autos
# if len(ubl_keys) > 0:
#     print('.'.join(['_'.join(str(ant) for ant in ap) for ap in ubl_keys]))
# else:
#     print('none')
# ")

# if [ "$antpairs_str" = "none" ]; then
#     echo "No antpairs match this input file. Exiting..."
#     exit 0
# fi
# #TODO: add JD to filename
# nb_outfile="$(cd "$(dirname "$fn")" && pwd)/single_baseline_files/zen.baseline.${antpairs_str}.sum.single_baseline_2D_filtered_SNRs.html"

# # Execute jupyter notebook
# jupyter nbconvert --output=${nb_outfile} \
# --to html \
# --ExecutePreprocessor.timeout=-1 \
# --execute ${nb_template_dir}/single_baseline_2D_filtered_SNRs.ipynb
# echo Finished running 2D DPSS filtering of single baseline SNRs notebook at $(date)

# # check for output files
# # TODO: fix
# # (python -c "
# # import os
# # for antpair '${antpairs_str}'.split('.'):
# #     assert os.path.exists('${SINGLE_BL_FILE_PATH}'.replace('{bl}', antpair).replace('.uvh5', '${SNR_SUFFIX}'))
# # ")

# # TODO
# # if [[ "$nb_outfile" == *".0_4."* ]]; then
# #     cp ${nb_outfile} ${nb_output_repo}/
# # fi


# # TODO
# # is_fourth_file=`python -c "import glob; files=sorted(glob.glob('zen.*${jd}*.sum.uvh5')); print('${fn}' == files[4])"`
# # if [ "${is_fourth_file}" == "True" ]; then
# #     # Copy file to github repo
# #     github_nb_outdir=${nb_output_repo}/file_calibration
# #     github_nb_outfile=${github_nb_outdir}/file_calibration_${jd}.html
# #     cp ${nb_outfile} ${github_nb_outfile}
# # fi
