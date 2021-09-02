#! /bin/bash
set -e
source ${src_dir}/_common.sh

fn="${1}"
data_folder="${2}"
cal_folder="${3}"
secrets_dir="${4}"
gps=$(get_gps $fn)

# copy settings.yaml and secrets to current dir
cp ${secrets_dir}/settings.yaml ./
cp ${secrets_dir}/client_secrets.json ./
chmod g-rwx settings.yaml
chmod o-rwx client_secrets.json


echo mwa_download_gdrive.py --data_folder ${data_folder} --cal_folder ${cal_folder} --gpstime ${gps}
mwa_download_gdrive.py --data_folder ${data_folder} --cal_folder ${cal_folder} --gpstime ${gps}

# remove secrets and settings.
rm -rf client_secrets.json
rm -rf settings.yaml
