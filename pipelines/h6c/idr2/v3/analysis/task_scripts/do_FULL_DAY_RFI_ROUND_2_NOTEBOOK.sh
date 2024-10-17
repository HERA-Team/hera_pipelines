#! /bin/bash
set -e

# This script generates an HTML version of a notebook which performs second-round full-day RFI flagging based on delay-filtered z-scores.
# It also zips up resultant UVFlag files and adds them to the librarian

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - upload_to_librarian: global boolean trigger
# 6 - librarian_full_day_rfi: boolean trigger for this step
# 7+ - various settings
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
upload_to_librarian=${5}
librarian_full_day_rfi=${6}
z_thresh=${7}
ws_z_thresh=${8}
avg_z_thresh=${9}
max_freq_flag_frac=${10}
max_time_flag_frac=${11}
avg_spectrum_filter_delay=${12}
eigenval_cutoff=${13}
time_avg_delay_filt_snr_thresh=${14}
time_avg_delay_filt_snr_dynamic_range=${15}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/full_day_rfi_round_2
nb_outfile=${nb_outdir}/full_day_rfi_round_2_${jd}.html

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export SUM_SUFFIX="sum.uvh5"
export SMOOTH_CAL_SUFFIX="sum.smooth.calfits"
export ZSCORE_SUFFIX="sum.red_avg_zscore.h5"
export FLAG_WATERFALL2_SUFFIX="sum.flag_waterfall_round_2.h5"
export OUT_YAML_SUFFIX="_aposteriori_flags.yaml"
export Z_THRESH=${z_thresh}
export WS_Z_THRESH=${ws_z_thresh}
export AVG_Z_THRESH=${avg_z_thresh}
export MAX_FREQ_FLAG_FRAC=${max_freq_flag_frac}
export MAX_TIME_FLAG_FRAC=${max_time_flag_frac}
export AVG_SPECTRUM_FILTER_DELAY=${avg_spectrum_filter_delay}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export TIME_AVG_DELAY_FILT_SNR_THRESH=${time_avg_delay_filt_snr_thresh}
export TIME_AVG_DELAY_FILT_SNR_DYNAMIC_RANGE=${time_avg_delay_filt_snr_dynamic_range}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/full_day_rfi_round_2.ipynb
echo Finished full-day rfi round 2 notebook at $(date)

# Check to see that at least one output file was correctly produced
first_outfile=${SUM_FILE%.sum.uvh5}.sum.flag_waterfall_round_2.h5
if [ -f "$first_outfile" ]; then
    echo Resulting $first_outfile found.
else
    echo $first_outfile not produced.
    exit 1
fi

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_full_day_rfi}" == "True" ]; then

        # Compress all ant_metrics files into one with a JD corresponding to $fn
        compressed_file=`echo ${fn%.uvh5}.flag_waterfall_round_2.h5.tar.gz`
        echo tar czfv ${compressed_file} zen.${jd}*.flag_waterfall_round_2.h5
        tar czfv ${compressed_file} zen.${jd}*.flag_waterfall_round_2.h5

        # Upload gzipped file to the librarian
        librarian_file=`basename ${compressed_file}`
        echo librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
        librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
        echo Finished uploading ${compressed_file} to the Librarian at $(date)
    fi
fi

# If desired, push results to github
if [ "${git_push}" == "True" ]
then
    cd ${nb_output_repo}
    git pull origin main || echo 'Unable to git pull origin main. Perhaps the internet is down?'
    git add ${nb_outfile}
    python ${src_dir}/build_notebook_readme.py ${nb_outdir}
    git add ${nb_outdir}/README.md
    lasturl=`python -c "readme = open('${nb_outdir}/README.md', 'r'); print(readme.readlines()[-1].split('(')[-1].split(')')[0])"`
    git commit -m "Full-Day RFI Round 2 notebook for JD ${jd}" -m ${lasturl}
    git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
fi
