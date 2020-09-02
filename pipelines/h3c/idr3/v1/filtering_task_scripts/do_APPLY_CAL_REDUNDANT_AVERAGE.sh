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
# 4 - baselines to load at once.
# 5 - polarizations to output. 
# POLARIZATION SELECTION HAS NOT YET BEEN IMPLEMENTED IN HERA-CAL

fn="${1}"
label="${2}"
output_ext="${3}"
nbl_per_load="${4}"
pols="${@:4}"

jd=$(get_jd $fn)

calfile=${fn%.uvh5}.${label}.smooth_abs.calfits
outfile=${fn%.uvh5}.${label}.${output_ext}

echo apply_cal.py  ${fn} ${outfile} \
--nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile}

apply_cal.py ${fn} ${outfile} \
--nbl_per_load ${nbl_per_load} --redundant_average --clobber  --new_cal ${calfile}
