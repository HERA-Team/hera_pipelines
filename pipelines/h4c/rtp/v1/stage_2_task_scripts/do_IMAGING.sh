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

# renumber antennas because any antenna numbers above 256 break casa
echo renumber_ants.py ${uvfits_file} ${uvfits_file} --overwrite --verbose
renumber_ants.py ${uvfits_file} ${uvfits_file} --overwrite --verbose

# get uvfits and ms filename
image_file="${uvfits_file%.uvfits}"
ms_file="${uvfits_file%.uvfits}.ms"

# call opm_imaging.py from CASA_IMAGING package
echo ${casa} -c ${casa_imaging_scripts}/opm_imaging.py --uvfitsname ${uvfits_file} --image ${image_file} --spw ${spw}
${casa} -c ${casa_imaging_scripts}/opm_imaging.py --uvfitsname ${uvfits_file} --image ${image_file} --spw ${spw}


# get model visibility files
echo get_model_vis.py ${filename} "'${model_vis}'" "./"
get_model_vis.py ${filename} "'${model_vis}'" "./"
model_file=`basename ${filename%.uvh5}.model.uvfits`
res_file=`basename ${filename%.uvh5}.res.uvfits`

# renumber antennas because any antenna numbers above 256 break casa
echo renumber_ants.py ${model_file} ${model_file} --overwrite --verbose
renumber_ants.py ${model_file} ${model_file} --overwrite --verbose
echo renumber_ants.py ${res_file} ${res_file} --overwrite --verbose
renumber_ants.py ${res_file} ${res_file} --overwrite --verbose

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
shopt -s nullglob # skip loop if nothing is found, e.g. if the file is totally flagged
for ff in *spw?.stokpol.image.fits
do
    # stokes I, Q, U, V
    echo plot_fits.py ${ff} --cmap bone_r,coolwarm,coolwarm,coolwarm --vmin 0,-5,-3,-3 --vmax 10,5,3,3 --radius 20
    plot_fits.py ${ff} --cmap bone_r,coolwarm,coolwarm,coolwarm --vmin 0,-5,-3,-3 --vmax 10,5,3,3 --radius 20
done
# collect vispol FITS output
shopt -s nullglob # skip loop if nothing is found, e.g. if the file is totally flagged
for ff in *spw?.vispol.image.fits
do
    # XX, YY
    echo plot_fits.py ${ff} --cmap bone_r --vmin 0 --vmax 10 --radius 20
    plot_fits.py ${ff} --cmap bone_r --vmin 0 --vmax 10 --radius 20
done

# erase uvfits file
if [ -f ${uvfits_file} ]; then
    echo rm -rf ${uvfits_file}
    rm -rf ${uvfits_file}
else
    echo Could not find ${uvfits_file} to delete.
fi

if [ -f ${uvfits_file%.uvfits}.ms ]; then
    echo rm -rf ${uvfits_file%.uvfits}.ms
    rm -rf ${uvfits_file%.uvfits}.ms
else
    echo Could not find ${uvfits_file%.uvfits}.ms to delete.
fi

if [ -f ${model_file} ]; then
    echo rm -rf ${model_file}
    rm -rf ${model_file}
else
    echo Could not find ${model_file} to delete.
fi

if [ -d ${model_file%.uvfits}.ms ]; then
    echo rm -rf ${model_file%.uvfits}.ms
    rm -rf ${model_file%.uvfits}.ms
else
    echo Could not find ${model_file%.uvfits}.ms to delete.
fi

if [ -f ${res_file} ]; then
    echo rm -rf ${res_file}
    rm -rf ${res_file}
else
    echo Could not find ${res_file} to delete.
fi

if [ -d ${res_file%.uvfits}.ms ]; then
    echo rm -rf ${res_file%.uvfits}.ms
    rm -rf ${res_file%.uvfits}.ms
else
    echo Could not find ${res_file%.uvfits}.ms to delete.
fi

# remove calibrated visibility
if [ ! -z "${calibration}" ]; then
    echo rm ${filename}
    rm ${filename}
fi
