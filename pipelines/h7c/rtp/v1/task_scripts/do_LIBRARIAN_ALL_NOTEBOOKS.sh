#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Parameters are set in the configuration file. Here we define their positions,
# which must be consisten wtih the config.
# 1 - filename
# 2 - upload_to_librarian: global boolean trigger
# 3 - librarian_notebooks: boolean trigger for this step
# 4 - nb_output_repo: repository for saving evaluated notebooks
fn="${1}"
upload_to_librarian="${2}"
librarian_notebooks="${3}"
nb_output_repo="${4}"

if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_notebooks}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn})
        decimal_jd=$(get_jd ${fn})

        declare -a nb_names=(
            "data_inspect_all_ants"
            "antenna_classification_summary"
            "full_day_rfi"
            "full_day_antenna_flagging"
            "full_day_auto_checker"
            "calibration_smoothing"
            "delay_filtered_average_zscore"
            "full_day_rfi_round_2"
            "file_postprocessing"
            "full_day_systematics_inspect"
        )

        for nb_name in ${nb_names[@]}; do
            nb_outfile=${nb_output_repo}/${nb_name}/${nb_name}_${jd}.ipynb
            # if the notebook doesn't exist, check to see whether there's an html file instead
            if [ ! -f "$nb_outfile" ]; then
                nb_outfile=${nb_outfile%.ipynb}.html
            fi
            if [ -f "$nb_outfile" ]; then
                nb_basename=$(basename "${nb_outfile}")
                echo librarian upload local-rtp ${nb_outfile} ${jd}/zen.${decimal_jd}.${nb_basename}
                librarian upload local-rtp ${nb_outfile} ${jd}/zen.${decimal_jd}.${nb_basename}
                echo Finished adding ${nb_outfile} to Librarian at $(date)
            fi
        done
    fi
fi
