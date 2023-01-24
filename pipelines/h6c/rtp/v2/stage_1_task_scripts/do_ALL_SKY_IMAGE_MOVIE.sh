set -e

#This script smashes a stack of jpgs into a movie. Used for widefield broadband RFI imaging.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# the only input we need is the filename
fn=${1}
CASA_ENV=${2}

# Get the integer JD from filename
jd=$(get_int_jd ${fn})
#put all the jpgs into a sub-dir for easy stacking with a ffmpeg glob
mkdir -p ${jd}_imgs
mv *${jd}*jpg ${jd}_imgs

conda activate $CASA_ENV
#image stack is in its own dir because glob dereferencing is hard
cd ${jd}_imgs
ffmpeg -f image2 -pattern_type glob -i '*.jpg' HERA_${jd}_automatic.mp4
cp  HERA_${jd}_automatic.mp4 ..
# TODO put movie in Librarian and upload to enterprise for quick online viewing
