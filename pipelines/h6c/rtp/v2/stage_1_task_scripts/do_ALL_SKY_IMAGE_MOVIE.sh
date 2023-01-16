set -e

# This script generates an HTML version of a notebook summarizing the output of auto_metrics, ant_metrics, and redcal chisq

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2 - nb_template_dir: where to look for the notebook template
# 3 - nb_output_repo: repository for saving evaluated notebooks
# 4 - git_push: boolean whether to push the results created in the nb_output_repo
# 5 - good_statuses: string list of comma-separated (no spaces) antenna statuses considered "good"

fn=${1}

# Get JD from filename
jd=$(get_int_jd ${fn})



#image stack is in its own dir because glob dereferencing is hard
cd ${jd}_imgs
ffmpeg -f image2 -pattern_type glob -i '*.jpg' HERA_${jd}_automatic.mp4
cp  HERA_${jd}_automatic.mp4 ..
# TODO put movie in Librarian and upload to enterprise for quick online viewing
cd ..
#cleanup
rm -rf ${jd}_imgs
