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
# 6 - calibration extension.


fn="${1}"
labelin="${2}"
label="${3}"
output_ext="${4}"
nbl_per_load="${5}"
pol0="${6}"
pol1="${7}"
flag_ext="${8}"
cal_ext="${9}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

flagfile=zen.${int_jd}.${flag_ext}
#infile=zen.${jd}.sum.${label}.chunked.${output_ext}
infile_diff=${infile/sum/diff}

auto_file=zen.${jd}.sum.${labelin}.autos.chunked.uvh5
outfile_auto=zen.${jd}.sum.${label}.autos.calibrated.uvh5
auto_file_diff=${auto_file/sum/diff}
outfile_auto_diff=${outfile_auto/sum/diff}


calfile=${fn%.uvh5}.${labelin}.chunked.${cal_ext}
diff_file=${fn/sum/diff}


if [ -e "${auto_file}" ]
then
  # calibrate sum autos. DO NOT REDUNDANT AVERAGE.
  echo apply_cal.py ${auto_file} ${outfile_auto} \
  --nbl_per_load ${nbl_per_load} --clobber  --new_cal ${calfile}

  apply_cal.py ${auto_file} ${outfile_auto} \
  --nbl_per_load ${nbl_per_load} --clobber  --new_cal ${calfile}

  # calibrate diff autos. DO NOT REDUNDANT AVERAGE.
  echo apply_cal.py ${auto_file_diff} ${outfile_auto_diff} \
  --nbl_per_load ${nbl_per_load} --clobber  --new_cal ${calfile}

  apply_cal.py ${auto_file_diff} ${outfile_auto_diff} \
  --nbl_per_load ${nbl_per_load} --clobber  --new_cal ${calfile} 


else
  echo "${auto_file} does not exist!"
fi
