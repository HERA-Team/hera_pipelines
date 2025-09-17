#! /bin/bash
set -e

# This script generates an HTML version of a notebook which performs full-day RFI flagging. It also zips up
# resultant UVFlag files and adds them to the librarian

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - upload_to_librarian: global boolean trigger
# 5 - librarian_full_day_rfi: boolean trigger for this step
# 6+ - various settings
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
upload_to_librarian=${4}
librarian_full_day_rfi=${5}
FM_low_freq=${6}
FM_high_freq=${7}
max_solar_alt=${8}
freq_filter_scale=${9}
time_filter_scale=${10}
eigenval_cutoff=${11}
min_frac_of_autos=${12}
max_auto_L2=${13}
z_thresh=${14}
ws_z_thresh=${15}
avg_z_thresh=${16}
repeat_flag_z_thresh=${17}
max_freq_flag_frac=${18}
max_time_flag_frac=${19}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/full_day_rfi
nb_outfile=${nb_outdir}/full_day_rfi_${jd}.html

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export SUM_SUFFIX="sum.uvh5"
export SUM_AUTOS_SUFFIX="sum.autos.uvh5"
export DIFF_AUTOS_SUFFIX="diff.autos.uvh5"
export CAL_SUFFIX="sum.omni.calfits"
export ANT_CLASS_SUFFIX="sum.ant_class.csv"
export OUT_FLAG_SUFFIX="sum.flag_waterfall.h5"
export FM_LOW_FREQ=${FM_low_freq}
export FM_HIGH_FREQ=${FM_high_freq}
export MAX_SOLAR_ALT=${max_solar_alt}
export FREQ_FILTER_SCALE=${freq_filter_scale}
export TIME_FILTER_SCALE=${time_filter_scale}
export EIGENVAL_CUTOFF=${eigenval_cutoff}
export MIN_FRAC_OF_AUTOS=${min_frac_of_autos}
export MAX_AUTO_L2=${max_auto_L2}
export Z_THRESH=${z_thresh}
export WS_Z_THRESH=${ws_z_thresh}
export AVG_Z_THRESH=${avg_z_thresh}
export REPEAT_FLAG_Z_THESH=${repeat_flag_z_thresh}
export MAX_FREQ_FLAG_FRAC=${max_freq_flag_frac}
export MAX_TIME_FLAG_FRAC=${max_time_flag_frac}
export APRIORI_YAML_PATH="$(cd "$(dirname "$fn")" && pwd)/"${jd}"_apriori_flags.yaml"

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/full_day_rfi.ipynb
echo Finished full-day rfi notebook at $(date)

# Check to see that at least one output file was correctly produced
first_outfile=${SUM_FILE%.sum.uvh5}.sum.flag_waterfall.h5
if [ -f "$first_outfile" ]; then
    echo Resulting $first_outfile found.
else
    echo $first_outfile not produced.
    exit 1
fi

# Rebuild index.html for this notebook's folder
python ${src_dir}/build_notebook_index.py ${nb_outdir}

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_full_day_rfi}" == "True" ]; then

        # Compress all flag_waterfall files into one with a JD corresponding to $fn
        compressed_file=`echo ${fn%.uvh5}.flag_waterfall.h5.tar.gz`
        echo tar czfv ${compressed_file} zen.${jd}*.flag_waterfall.h5
        tar czfv ${compressed_file} zen.${jd}*.flag_waterfall.h5

        # Upload gzipped file to the librarian
        librarian_file=`basename ${compressed_file}`
        echo librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
        librarian upload local-rtp ${compressed_file} ${jd}/${librarian_file}
        echo Finished uploading ${compressed_file} to the Librarian at $(date)
    fi
fi
