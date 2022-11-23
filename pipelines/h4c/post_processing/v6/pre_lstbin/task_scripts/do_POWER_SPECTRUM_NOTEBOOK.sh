#! /bin/bash

#-----------------------------------------------------------------------------
# This script computes night power spectra as part of the nightly post
# processing pipeline.
#-----------------------------------------------------------------------------


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
#    https://github.com/HERA-Team/hera_notebook_templates/blob/master/notebooks/power_spectrum_inspect.ipynb
# 3) nb_output_repo: Location of repository where you plan on saving evaluated notebooks
#    This should probably be deprecated due to Githubs relatively limited storage.
# 4) git_push: boolean whether to push the results created to nb_output_repo
# 5) label: identifier label.
# 6) spws: list of integers of spectral windows in pspec objects
#    to inspect separated by commas with no spaces: e.g. "0,1,2"
# 7) list of lst ranges with lower/upper of each range separated by tildes and each field by commas.
#    NO SPACES. Example: 1~3,4.2~6.2 will trigger inspecting fields with LST range 1-3 hours and 4.2-6.2 hours.
# 8) Inspect every N redundant baseline groups when breaking redundant groups out into individual baselines.
# 9) Number of baseline pairs to skip when processing blpair average plots.
# 10) labels for each LST field spearated by commas with no spaces. Ex: "1, 2".
# 11) max_plots_per_row: Name is what it says.
#
# 1) Xtalk filtered, delay inpainted, time averaged sum/diff power spectra with
#    pstokes I polarization naming format
#    zen.${jd}.${sd}.${label}.${ext}.xtalk_filtered${pol_label}.tavg.pspec.h5
# 2) Beam file with naming convention
#    ${beamfile_stem}${pol_label}.fits
#
# OUTPUTS:
# 1) Notebook output written to ${nb_output_repo}.
#    ${nb_output_repo}/power_spectrum_inspect/power_spectrum_inspect_${label}_${int_jd}_${ext}.ipynb
#
#-----------------------------------------------------------------------------



fn=${1}
nb_template_dir=${2}
nb_output_repo=${3}
git_push=${4}
label=${5}
spws=${6}
lst_fields=${7}
grp_skip=${8}
blp_skip=${9}
field_labels=${10}
max_plots_per_row=${11}


# Get JD from filename
# Get JD from filename
jd=$(get_jd $fn)
int_jd=${jd:0:7}
exts=("foreground_filled")

for ext in ${exts[@]}
do
  nb_outfile=${nb_output_repo}/power_spectrum_inspect/power_spectrum_inspect_${label}_${int_jd}_${ext}.ipynb
  # Export variables used by the notebook
  export DATA_PATH=`pwd`
  export JULIANDATE=${int_jd}
  export LABEL=${label}
  export SPWS=${spws}
  export LST_FIELDS=${lst_fields}
  export GRP_SKIP=${grp_skip}
  export BLP_SKIP=${blp_skip}
  export FIELD_LABELS=${field_labels}
  export MAX_PLOTS_PER_ROW=${max_plots_per_row}
  export EXT=${ext}

  # Execute jupyter notebook
  jupyter nbconvert --output=${nb_outfile} \
  --to notebook \
  --ExecutePreprocessor.allow_errors=True \
  --ExecutePreprocessor.timeout=-1 \
  --execute ${nb_template_dir}/power_spectrum_inspect.ipynb
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
