#! /bin/bash
set -e
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn="${1}"
data_folder="${2}"
cal_folder="${3}"
secrets_dir="${4}"
gps=$(get_gps $fn)

# copy settings.yaml and secrets to current dir
if [ ! -f "client_secrets.json" ]
then
  cp ${secrets_dir}/client_secrets.json ./
fi
if [ ! -f "settings.yaml" ]
then
  cp ${secrets_dir}/settings.yaml ./
fi

chmod g-rwx settings.yaml
chmod o-rwx client_secrets.json


echo mwa_download_gdrive.py --data_folder ${data_folder} --cal_folder ${cal_folder} --gpstime ${gps}
mwa_download_gdrive.py --data_folder ${data_folder} --cal_folder ${cal_folder} --gpstime ${gps}
