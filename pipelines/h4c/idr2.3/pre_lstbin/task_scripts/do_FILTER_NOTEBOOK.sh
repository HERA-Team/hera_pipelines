#! /bin/bash

set -e
# sometimes /tmp gets filled up on NRAO nodes hence this line.
# haven't need to use it recently.
#export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/
#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


#-----------------------------------------------------------------------------
# ARGUMENTS
# 1) fn: Input filename (string) assumed to contain JD.
# 2) nb_template_dir: Directory where to look for the notebook template. This should
#    be wherever you've installed a copy of
#    https://github.com/HERA-Team/hera_notebook_templates/blob/master/notebooks/filter_inspect.ipynb
# 3) nb_output_repo: Location of repository where you plan on saving evaluated notebooks
#    This should probably be deprecated due to Githubs relatively limited storage.
# 4) git_push: boolean whether to push the results created to nb_output_repo
# 5) label: identifier label.
# 6) nreds: number of redundant groups to show in plots.
# 7) max_bl_per_redgrp: Maximum number of baselines to show per redundant group.
# 8) nskip: number of redundant groups to skip over when
#    plotting the number of redundant groups specified in $6.
# 9) spws:
#
#
# ASSUMED INPUTS
# 1) Xtalk filtered, delay inpainted, time averaged sum/diff data files.
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered.tavg.uvh5
#    where ext="foreground_filled"
# 1) Delay inpainted, time averaged sum/diff data files.
#    zen.${jd}.${sd}.${label}.${ext}.tavg.uvh5
#    where ext="foreground_filled"
#
# OUTPUTS:
# 1) Notebook output written to ${nb_output_repo}.
#    nb_outfile=${nb_output_repo}/filter_inspect/filter_inspect_${label}_${jd}_${ext}.ipynb
#
#-----------------------------------------------------------------------------


fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
label=${5}
nreds=${6}
max_bls_per_redgrp=${7}
nskip=${8}
spws=${9}

# Get JD from filename
jd=$(get_int_jd ${fn})
exts=("foreground_filled")

for ext in ${exts[@]}
do
  nb_outfile=${nb_output_repo}/filter_inspect/filter_inspect_${label}_${jd}_${ext}.ipynb

  # Export variables used by the notebook
  export DATA_PATH=`pwd`
  export JULIANDATE=${jd}
  export LABEL=${label}
  export NREDS=${nreds}
  export MAX_BLS_PER_REDGRP=${max_bls_per_redgrp}
  export NSKIP=${nskip}
  export SPWS=${spws}
  export EXT=${ext}
  # Execute jupyter notebook
  jupyter nbconvert --output=${nb_outfile} \
  --to notebook \
  --ExecutePreprocessor.allow_errors=True \
  --ExecutePreprocessor.timeout=-1 \
  --execute ${nb_template_dir}filter_inspect.ipynb

  # If desired, push results to github
  if [ "${git_push}" == "True" ]
  then
      cd ${nb_output_repo}
      git pull origin master
      git add ${nb_outfile}
      git commit -m "H4C RTP Filtering notebook for JD ${jd} ${label}"
      git push origin master
  fi
done
