#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - data filename
# 2 - path to casa executable
# 3 - casa imaging scripts dir
# 4 - spectral window (e.g. '0:150~900')
# 5 - model vis glob parseable path, set to None if unwanted
# 6 - calfits suffix (optional)
filename="${1}"
casa="${2}"
casa_imaging_scripts="${3}"
spw="${4}"
model_vis="${5}"
if [ "$#" -ge 6 ]; then
    calibration="${6}"
fi

# make an imaging dir for outputs
image_outdir="${filename}_image"
mkdir -p ${image_outdir}
cd ${image_outdir}
filename="../${filename}"

# if calibration suffix is not empty, parse it and apply it
if [ ! -z "${calibration}" ]; then
    # parse calibration suffix
    cal_file="${filename%.uvh5}.${calibration}"
    output=`basename ${filename%.uvh5}.calibrated.uvh5`
    echo apply_cal.py ${filename} ${output} --new_cal ${cal_file} --filetype_in uvh5 --filetype_out uvh5 --clobber
    apply_cal.py ${filename} ${output} --new_cal ${cal_file} --filetype_in uvh5 --filetype_out uvh5 --clobber
    filename="${output}"
fi

# convert file to uvfits
uvfits_file=`basename ${filename%.uvh5}.uvfits`
echo convert_to_uvfits.py ${filename} --output_filename ${uvfits_file} --overwrite
convert_to_uvfits.py ${filename} --output_filename ${uvfits_file} --overwrite

# get uvfits and ms filename
image_file="${uvfits_file%.uvfits}"
ms_file="${uvfits_file%.uvfits}.ms"

# call opm_imaging.py from CASA_IMAGING package
echo ${casa} -c ${casa_imaging_scripts}/opm_imaging.py --uvfitsname ${uvfits_file} --image ${image_file} --spw ${spw}
${casa} -c ${casa_imaging_scripts}/opm_imaging.py --uvfitsname ${uvfits_file} --image ${image_file} --spw ${spw}

# get model visibility files
echo python ${casa_imaging_scripts}/get_model_vis.py ${filename} "'${model_vis}'" "./"
python ${casa_imaging_scripts}/get_model_vis.py ${filename} "'${model_vis}'" "./"
model_file=`basename ${filename%.uvh5}.model.uvfits`
res_file=`basename ${filename%.uvh5}.res.uvfits`
# if it ran through, image model and residual
if [ -f ${model_file} ]; then
    echo ${casa} -c ${casa_imaging_scripts}/opm_imaging.py --uvfitsname ${model_file} --image ${model_file%.uvfits} --spw ${spw}
    ${casa} -c ${casa_imaging_scripts}/opm_imaging.py --uvfitsname ${model_file} --image ${model_file%.uvfits} --spw ${spw}
fi
if [ -f ${res_file} ]; then
    echo ${casa} -c ${casa_imaging_scripts}/opm_imaging.py --uvfitsname ${res_file} --image ${res_file%.uvfits} --spw ${spw}
    ${casa} -c ${casa_imaging_scripts}/opm_imaging.py --uvfitsname ${res_file} --image ${res_file%.uvfits} --spw ${spw}
fi

# collect stokpol FITS output
fits_files=(`ls *spw?.stokpol.image.fits`)
for ff in "${fits_files[@]}"
do
    # stokes I, Q, U, V
    echo python ${casa_imaging_scripts}/plot_fits.py ${ff} --cmap bone_r,coolwarm,coolwarm,coolwarm --vmin 0,-5,-3,-3 --vmax 10,5,3,3 --radius 20
    python ${casa_imaging_scripts}/plot_fits.py ${ff} --cmap bone_r,coolwarm,coolwarm,coolwarm --vmin 0,-5,-3,-3 --vmax 10,5,3,3 --radius 20
done
# collect vispol FITS output
fits_files=(`ls *spw?.vispol.image.fits`)
for ff in "${fits_files[@]}"
do
    # XX, YY
    echo python ${casa_imaging_scripts}/plot_fits.py ${ff} --cmap bone_r --vmin 0 --vmax 10 --radius 20
    python ${casa_imaging_scripts}/plot_fits.py ${ff} --cmap bone_r --vmin 0 --vmax 10 --radius 20
done

# erase uvfits file
if [ -f ${uvfits_file} ]; then
    echo rm ${uvfits_file}
    rm ${uvfits_file}
fi
if [ -f ${model_file} ]; then
    echo rm ${model_file}
    rm ${model_file}
fi
if [ -d ${model_file%.uvfits}.ms ]; then
    echo rm -r ${model_file%.uvfits}.ms
    rm -r ${model_file%.uvfits}.ms
fi
if [ -f ${res_file} ]; then
    echo rm ${res_file}
    rm ${res_file}
fi
if [ -d ${res_file%.uvfits}.ms ]; then
    echo rm -r ${res_file%.uvfits}.ms
    rm -r ${res_file%.uvfits}.ms
fi

# keep ms files for 2458098
JD=`get_jd "${1}" | cut -c 1-7`
if [ $JD -ne 2458098 ]; then
    echo rm ${ms_file}
    rm -r ${ms_file} || echo "No ${ms_file} to remove."
fi

# remove calibrated visibility
if [ ! -z "${calibration}" ]; then
    rm ${filename}
fi
