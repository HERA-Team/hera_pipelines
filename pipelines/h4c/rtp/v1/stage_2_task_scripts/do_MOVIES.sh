#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - data filename
# 2 - spectral window or windows (e.g. '0:150~900')
# 3 - path to ffmpeg executable
# 4 - frames per second
# 5 - movie size in pixels (e.g. 1280x720)
fn="${1}"
spw="${2}"
ffmpeg="${3}"
framerate="${4}"
framesize="${5}"

# get JD
jd=$(get_int_jd ${fn})

# count the number of commas in spw to get the number of spectral windows
commas="${spw//[^,]}"
(( nspw = "${#commas}" + 1 ))

# loop over data, model, and residual; stokes pol and vis pol; and over spectral windows
for dtype in "." ".model." ".res."; do
    for pol in stokpol vispol; do
        for n in `seq 0 ${nspw}`; do
            # make temporary directory (replacing periods with underscores) to store images in one place for using ffmpeg
            tempdir=${jd}.${dtype}spw${n}.${pol}_movie_temp
            tempdir=${tempdir//./_}
            # make new directory (deleting old if necessary) and cd into it and copy all pngs over
            rm -rf ${tempdir}
            mkdir ${tempdir}
            cd ${tempdir}
            for png in ../*_image/zen.${jd}.*.calibrated${dtype}spw${n}.${pol}.image.png; do
                cp ${png} .
            done

            # make movie
            echo ${ffmpeg} -framerate ${framerate} -pattern_type glob -i "./*.png" -s:v ${framesize} \
                -c:v libx264 -profile:v high -crf 20 -pix_fmt yuv420p zen.${jd}${dtype}spw${n}.${pol}.mp4
            ${ffmpeg} -framerate ${framerate} -pattern_type glob -i "./*.png" -s:v ${framesize} \
                -c:v libx264 -profile:v high -crf 20 -pix_fmt yuv420p zen.${jd}${dtype}spw${n}.${pol}.mp4

            # return to main analysis directory, move movie, remove tempdir
            cd ..
            mv ${tempdir}/zen.${jd}${dtype}spw${n}.${pol}.mp4 .
            rm -rf ${tempdir}
        done
    done

