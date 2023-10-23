#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# refresh the IERS table for calculating LST accurately. If it fails, echo that and move on since the cronjob is will probably take care of things.
python -c "from astropy.utils.iers import IERS_B_URL, IERS_B; from astropy.utils.data import download_file; IERS_B.open(download_file(IERS_B_URL, cache='update'))" || echo "Unable to update IERS table. Perhaps the internet is down?"
