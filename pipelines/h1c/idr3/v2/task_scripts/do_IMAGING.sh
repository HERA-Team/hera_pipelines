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

# make sure input file is correct uvh5 file
uvh5_fn=$(remove_pol $filename)
uvh5_fn=${uvh5_fn%.HH.uv}.sum.uvh5 # this makes things more compatible with H3C/H4C software

# make an imaging dir for outputs
image_outdir="${uvh5_fn}_image"
mkdir -p ${image_outdir}
cd ${image_outdir}
uvh5_fn="../${uvh5_fn}"

# if calibration suffix is not empty, parse it and apply it
if [ ! -z "${calibration}" ]; then
    # parse calibration suffix
    cal_file="${uvh5_fn%.uvh5}.${calibration}"
    output=`basename ${uvh5_fn%.uvh5}.calibrated.uvh5`
    echo apply_cal.py ${uvh5_fn} ${output} --new_cal ${cal_file} --filetype_in uvh5 --filetype_out uvh5 --clobber
    apply_cal.py ${uvh5_fn} ${output} --new_cal ${cal_file} --filetype_in uvh5 --filetype_out uvh5 --clobber
    uvh5_fn="${output}"
fi

# convert file to uvfits
uvfits_file=`basename ${uvh5_fn%.uvh5}.uvfits`
echo convert_to_uvfits.py ${uvh5_fn} --output_filename ${uvfits_file} --overwrite
convert_to_uvfits.py ${uvh5_fn} --output_filename ${uvfits_file} --overwrite

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
echo python ${casa_imaging_scripts}/get_model_vis.py --model_not_redundant ${uvh5_fn} "'${model_vis}'" "./"
python ${casa_imaging_scripts}/get_model_vis.py ${uvh5_fn} --model_not_redundant "'${model_vis}'" "./"
model_file=`basename ${uvh5_fn%.uvh5}.model.uvfits`
res_file=`basename ${uvh5_fn%.uvh5}.res.uvfits`

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
    echo python ${casa_imaging_scripts}/plot_fits.py ${ff} --cmap bone_r,coolwarm,coolwarm,coolwarm --vmin 0,-5,-3,-3 --vmax 10,5,3,3 --radius 20
    python ${casa_imaging_scripts}/plot_fits.py ${ff} --cmap bone_r,coolwarm,coolwarm,coolwarm --vmin 0,-5,-3,-3 --vmax 10,5,3,3 --radius 20
done
# collect vispol FITS output
shopt -s nullglob # skip loop if nothing is found, e.g. if the file is totally flagged
for ff in *spw?.vispol.image.fits
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
if [ -d ${uvfits_file%.uvfits}.ms ]; then
    echo rm -r ${uvfits_file%.uvfits}.ms
    rm -r ${uvfits_file%.uvfits}.ms
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

# remove calibrated visibility
if [ ! -z "${calibration}" ]; then
    echo rm ${uvh5_fn}
    rm ${uvh5_fn}
fi
