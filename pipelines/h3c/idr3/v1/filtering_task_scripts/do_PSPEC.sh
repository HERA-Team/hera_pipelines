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
beam_file="${4}"
jd=$(get_jd $fn)
int_jd=${jd:0:7}

even_file=zen.${jd}.even.${label}.xtalk_filtered_res.${data_ext}
odd_file=${even_file/even/odd}

output=zen.${jd}.${label}.xtalk_filtered_res.uvp
# form power spectrum between even and odd data sets with offset times.

echo pspec_run.py --allow_fft --store_cov_diag\
 --vis_units Jy --cov_model empirical_pspec --overwrite\
 --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
 --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}

pspec_run.py --allow_fft --store_cov_diag\
  --vis_units Jy --cov_model empirical_pspec --overwrite\
  --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
  --Jy2mK --beam ${beam_file} --interleave_times --sampling\
  --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}


even_file=zen.${jd}.even.${label}.foreground_filtered_filled.${data_ext}
odd_file=${even_file/even/odd}
output=zen.${jd}.${label}.foreground_filtered_filled.uvp
# form power spectrum between even and odd data sets with offset times.

echo pspec_run.py --allow_fft --store_cov_diag\
 --vis_units Jy --cov_model empirical_pspec --overwrite\
 --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
 --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}

pspec_run.py --allow_fft --store_cov_diag\
  --vis_units Jy --cov_model empirical_pspec --overwrite\
  --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
  --Jy2mK --beam ${beam_file} --interleave_times --sampling\
  --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}
