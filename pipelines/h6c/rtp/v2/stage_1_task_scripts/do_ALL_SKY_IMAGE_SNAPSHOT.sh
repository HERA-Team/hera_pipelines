#! /bin/bash
set -e

echo "do_ALL_SKY_IMAGE_SNAPSHOT"
hostname
#This script generates an all-sky image of the sky as a jpg
# a subsequent job collects them all into an image

# for now assumes scripts are to be found in ~/bin/



src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
fn=${1}
UVDATA_ENV="${2}"
CASA_ENV="${3}"

# Export variables used by the notebook
export SUM_FILE="$(cd "$(dirname "$fn")" && pwd)/$(basename "$fn")"
#CALFILE=/lustre/aoc/projects/hera/H6C/2459853/zen.2459853.35006.sum.omni.calfits

echo "conda activate $UVDATA_ENV"
#take a raw HERA snapshot to widefield image and render it as a jpg
conda activate $UVDATA_ENV
#step 1 make a calibrated MS.  read raw, apply cal, write ms
# comment --cal_file to LET CAL FLOAT
echo "python ~/bin/uvh5tocalibratedms.py ${SUM_FILE}"
python ~/bin/uvh5tocalibratedms.py ${SUM_FILE} # --cal_file ${CALFILE}

#step 2 image the ms
## 2.1 use my awesome casa env
echo "conda activate $CASA_ENV"
conda activate $CASA_ENV
## 2.2 fung up the name of the file I made above
MSFILE=$(python -c "import os; print(os.path.basename('${SUM_FILE}').replace('uvh5','ms'))")
## 2.3 time to synth-e-size
echo "python ~/bin/hera_widefield_image.py  $MSFILE "
python ~/bin/hera_widefield_image.py  $MSFILE 

#step 3 render to a jpg
# 3.1 rabble together the fits filename
IMAGEFILE=$(python -c "import os; print('${MSFILE}'.replace('ms','v1.fits'))")
echo "IMAGEFILE:" ${IMAGEFILE}
# 3.2 get back to my bleedin edge python3.10 env
conda activate $UVDATA_ENV
# 3.3 make killer jpg
python ~/bin/widefield_fits2img.py $IMAGEFILE

#CLEANUP
#put all the jpgs into a sub-dir for easy stacking later
#jd=$(get_int_jd ${fn})
#mkdir ${jd}_imgs
#mv *${jd}*jpg ${jd}_imgs

# delete ms, v1
rm -rf $MSFILE

