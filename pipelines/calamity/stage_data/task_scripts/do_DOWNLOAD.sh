#! /bin/bash
set -e
source ${src_dir}/_common.sh

fn="${1}"
folder="${2}"
gps=$(get_gps $fn)

echo mwa_download_gdrive.py --folder ${folder} --gpstime ${gps}
mwa_download_gdrive.py --folder ${folder} --gpstime ${gps}
