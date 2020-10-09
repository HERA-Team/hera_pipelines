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

jd=$(get_jd $fn)

auto_file = ${fn%.uvh5}.auto.uvh5
outfile_auto = ${fn%.uvh5}.${label}.calibrated.auto.uvh5

calfile=${fn%.uvh5}.${label}.smooth_abs.roto_flags.calfits
diff_file=${fn/sum/diff}
outfile=zen.${jd}.sum.${label}.${output_ext}
outfile_diff=zen.${jd}.diff.${label}.${output_ext}

#calibrate sum.
echo apply_cal.py  ${fn} ${outfile} \
--nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile} --overwrite_data_flags

apply_cal.py ${fn} ${outfile} \
--nbl_per_load ${nbl_per_load} --redundant_average --clobber  --new_cal ${calfile} --overwrite_data_flags

# calibrate diff.
echo apply_cal.py  ${diff_file} ${outfile_diff} \
--nbl_per_load ${nbl_per_load} --redundant_average --clobber --new_cal ${calfile} --overwrite_data_flags

apply_cal.py ${diff_file} ${outfile_diff} \
--nbl_per_load ${nbl_per_load} --redundant_average --clobber  --new_cal ${calfile} --overwrite_data_flags

# calibrate sum autos. DO NOT REDUNDANT AVERAGE.
apply_cal.py ${auto_file} ${outfile_auto}\
--nbl_per_load ${nbl_per_load} --clobber  --new_cal ${calfile} --overwrite_data_flags


# generate even / odd files.
outfile_even=${outfile/sum/even}
outfile_odd=${outfile/sum/odd}

echo sum_diff_2_even_odd.py ${outfile} ${outfile_diff} ${outfile_even} ${outfile_odd} --nbl_per_load ${nbl_per_load} --clobber

sum_diff_2_even_odd.py ${outfile} ${outfile_diff} ${outfile_even} ${outfile_odd} --nbl_per_load ${nbl_per_load} --clobber
