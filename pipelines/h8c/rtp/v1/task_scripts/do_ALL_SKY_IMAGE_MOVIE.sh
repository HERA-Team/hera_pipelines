#! /bin/bash
set -e

#This script smashes a stack of jpgs into a movie. Used for widefield broadband RFI imaging.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh
echo Host: `hostname`

# >>> conda initialize >>>
# contents within this block must be kept matching those in ~/.bashrc
__conda_setup="$('/home/obs/mambaforge/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/obs/mambaforge/etc/profile.d/conda.sh" ]; then
        . "/home/obs/mambaforge/etc/profile.d/conda.sh"
    else
        export PATH="/home/obs/mambaforge/bin:$PATH"
    fi
fi
unset __conda_setup

if [ -f "/home/obs/mambaforge/etc/profile.d/mamba.sh" ]; then
    . "/home/obs/mambaforge/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<

# the only input we need is the filename
fn=${1}
CASA_ENV=${2}

# Get the integer JD from filename
jd=$(get_int_jd ${fn})

conda activate $CASA_ENV

ffmpeg -f image2 -pattern_type glob -i 'zen*v1.jpg' HERA_${jd}_automatic.mp4
cp  HERA_${jd}_automatic.mp4 ..
# TODO put movie in Librarian and upload to enterprise for quick online viewing
# Put movie where it will be rsynced to heranow by a regular cron
cp  HERA_${jd}_automatic.mp4 /mnt/sn1/data1/nightly_movies/

#make sure the environment is the global env
conda activate RTP
