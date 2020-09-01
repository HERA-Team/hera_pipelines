#!/bin/bash
set -e

# import common funcitons
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh


# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - filename
### cal smoothing parameters - see hera_cal.smooth_cal for details
# 2 - identifying label for pipeline settings.
# 3 - output data extension.
# 4 - visibility units.
# 5 - number of baselines to process simultaneously
# 6 - lst_blacklists
# 7 - string for xrfi flag files to use. Provide none if no external flag files are to be used.
# 8 - spw range lower bound
# 9 - spw rnage upper bound
# 10 - output label for cal files.


fn="${1}"
label="${2}"
output_ext="${3}"
vis_units="${4}"
nbl_per_load="${5}"


jd=$(get_jd $fn)

calfile=${fn%.uvh5}.${label}.smooth_abs.calfits
outfile=${fn%.uvh5}.${label}.${output_ext}

echo apply_cal.py --vis_units ${vis_units} \
--nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile}\
 ${fn} ${outfile}

apply_cal.py  --vis_units ${vis_units} \
--nbl_per_load ${nbl_per_load} --redundant_average --clobber  --new_cal ${calfile}\
apply_cal.py  --vis_units ${vis_units} \
${fn} ${outfile}
