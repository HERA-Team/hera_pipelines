#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

#the args are
# 1 - input file name.
# 2 - data extension.
# 3 - label
# 4 - name of beamfits file.

# define input arguments
fn="${1}"
data_ext="${2}"
label="${3}"
beamfile="${4}"
jd=$(get_jd $fn)

even_file=zen.${jd}.even.${label}.xtalk_filtered_res.${data_ext}
odd_file=${even_file/even/odd}

output=zen.${jd}.${label}.xtalk_filtered_res.uvp
# form power spectrum between even and odd data sets with offset times.

echo pspec_run.py --dsets ${even_file} ${odd_file} --allow_fft --store_cov_diag\
 --filename ${output} --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg


pspec_run.py --dsets ${even_file} ${odd_file} --allow_fft --store_cov_diag\
 --filename ${output} --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg

 even_file=zen.${jd}.even.${label}.foreground_filtered_filled.${data_ext}
 odd_file=${even_file/even/odd}

 output=zen.${jd}.${label}.foreground_filtered_filled.uvp
 # form power spectrum between even and odd data sets with offset times.

 echo pspec_run.py --dsets ${even_file} ${odd_file} --allow_fft --store_cov_diag\
  --filename ${output} --Jy2mK --beam ${beam_file} --interleave_times --sampling\
  --time_avg


 pspec_run.py --dsets ${even_file} ${odd_file} --allow_fft --store_cov_diag\
  --filename ${output} --Jy2mK --beam ${beam_file} --interleave_times --sampling\
  --time_avg
