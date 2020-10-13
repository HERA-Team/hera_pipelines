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


fn="${1}"
label="${2}"
output_ext="${3}"
nbl_per_load="${4}"
pols="${5}"
flag_file="${6}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}


infile=${fn%.uvh5}.sum.${output_ext}
infile_diff=${infile/sum/diff}

auto_file=${fn%.uvh5}.autos.uvh5
outfile_auto=${fn%.uvh5}.${label}.autos.calibrated.uvh5
auto_file_diff=${auto_file/sum/diff}
outfile_auto_diff=${outfile_auto/sum/diff}


flagfile=zen.${jd}.${label}.roto_flags.flags.h5
calfile=${fn%.uvh5}.${label}.smooth_abs.roto_flags.calfits
diff_file=${fn/sum/diff}
outfile=zen.${jd}.sum.${label}.${output_ext}
outfile_diff=zen.${jd}.diff.${label}.${output_ext}


# calibrate sum autos. DO NOT REDUNDANT AVERAGE.
echo apply_cal.py ${auto_file} ${outfile_auto} \
--nbl_per_load ${nbl_per_load} --clobber  --new_cal ${calfile} --overwrite_data_flags

apply_cal.py ${auto_file} ${outfile_auto} \
--nbl_per_load ${nbl_per_load} --clobber  --new_cal ${calfile} --overwrite_data_flags

# calibrate diff autos. DO NOT REDUNDANT AVERAGE.
echo apply_cal.py ${auto_file_diff} ${outfile_auto_diff} \
--nbl_per_load ${nbl_per_load} --clobber  --new_cal ${calfile} --overwrite_data_flags

apply_cal.py ${auto_file_diff} ${outfile_auto_diff} \
--nbl_per_load ${nbl_per_load} --clobber  --new_cal ${calfile} --overwrite_data_flags

# generate even / odd files.
outfile_even=${outfile/sum/even}
outfile_odd=${outfile/sum/odd}
outfile_even_auto=${outfile_auto/sum/even}
outfile_odd_auto=${outfile_auto/sum/odd}

echo sum_diff_2_even_odd.py ${outfile_auto} ${outfile_auto_diff} ${outfile_even_auto} ${outfile_odd_auto} \
--nbl_per_load ${nbl_per_load} --clobber \
--polarizations ${pols}
sum_diff_2_even_odd.py ${outfile_auto} ${outfile_auto_diff} ${outfile_even_auto} ${outfile_odd_auto} \
--nbl_per_load ${nbl_per_load} --clobber \
--polarizations ${pols}


echo sum_diff_2_even_odd.py ${outfile} ${outfile_diff} ${outfile_even} ${outfile_odd}\
 --nbl_per_load ${nbl_per_load} --clobber \
--overwrite_data_flags --external_flags ${flagfile} --polarizations ${pols}
sum_diff_2_even_odd.py ${outfile} ${outfile_diff} ${outfile_even} ${outfile_odd}\
 --nbl_per_load ${nbl_per_load} --clobber \
--overwrite_data_flags --external_flags ${flagfile} --polarizations ${pols}
