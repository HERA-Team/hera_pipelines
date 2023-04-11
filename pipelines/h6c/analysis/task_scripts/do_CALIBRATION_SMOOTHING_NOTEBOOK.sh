#! /bin/bash
set -e

# This script generates an HTML version of a notebook which performs calibration smoothing.
# It also zips up resultant calfits files and adds them to the librarian, if desired.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - upload_to_librarian: global boolean trigger
# 6 - librarian_smooth_cal: boolean trigger for this step
# 7+ - various settings
fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
upload_to_librarian=${5}
librarian_smooth_cal=${6}
freq_smoothing_scale=${7}
time_smoothing_scale=${8}
eigenval_cutoff=${9}

# Get JD from filename
jd=$(get_int_jd ${fn})
nb_outdir=${nb_output_repo}/calibration_smoothing
nb_outfile=${nb_outdir}/calibration_smoothing_${jd}.html

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
export SUM_SUFFIX="sum.uvh5"
export CAL_SUFFIX="sum.omni.calfits"
export SMOOTH_CAL_SUFFIX="sum.smooth.calfits"
export ANT_FLAG_SUFFIX="sum.antenna_flags.h5"
export RFI_FLAG_SUFFIX="sum.flag_waterfall.h5"
export OUT_YAML_SUFFIX = "_aposteriori_flags.yaml"
export FREQ_SMOOTHING_SCALE=${freq_smoothing_scale}
export TIME_SMOOTHING_SCALE=${time_smoothing_scale}
export EIGENVAL_CUTOFF=${eigenval_cutoff}

# Execute jupyter notebook and save as HTML
jupyter nbconvert --output=${nb_outfile} \
--to html \
--ExecutePreprocessor.timeout=-1 \
--execute ${nb_template_dir}/calibration_smoothing.ipynb
echo Finished calibration smoothing notebook at $(date)

# Check to see that at least one output file was correctly produced
first_outfile=${SUM_FILE%.sum.uvh5}.sum.smooth.calfits
if [ -f "$first_outfile" ]; then
    echo Resulting $first_outfile found.
else
    echo $first_outfile not produced.
    exit 1
fi

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_smooth_cal}" == "True" ]; then

        # Compress all ant_metrics files into one with a JD corresponding to $fn
        compressed_file=`echo ${fn%.uvh5}.smooth.calfits.tar.gz`
        echo tar czfv ${compressed_file} zen.${jd}*.smooth.calfits
        tar czfv ${compressed_file} zen.${jd}*.smooth.calfits

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
    git commit -m "Calibration smoothing notebook for JD ${jd}" -m ${lasturl}
    git push origin main || echo 'Unable to git push origin main. Perhaps the internet is down?'
fi
