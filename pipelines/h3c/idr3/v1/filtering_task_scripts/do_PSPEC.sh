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

even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_noforegrounds_res.${data_ext}
odd_file=${even_file/even/odd}

output=zen.${jd}.${label}.xtalk_filtered_waterfall_noforegrounds_res.uvp
# form power spectrum between even and odd data sets with offset times.


# power spectra of data with no foregrounds or xtalk.
echo pspec_run.py --allow_fft --store_cov_diag\
 --vis_units Jy --cov_model empirical_pspec --overwrite\
 --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
 --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}\
 --taper bh

pspec_run.py --allow_fft --store_cov_diag\
  --vis_units Jy --cov_model empirical_pspec --overwrite\
  --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
  --Jy2mK --beam ${beam_file} --interleave_times --sampling\
  --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}\
  --taper bh

  # power spectra of data with foregrounds but no xtalk.
even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_res.${data_ext}
odd_file=${even_file/even/odd}
output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.uvp

echo pspec_run.py --allow_fft --store_cov_diag\
 --vis_units Jy --cov_model empirical_pspec --overwrite\
 --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
 --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}\
 --taper bh

pspec_run.py --allow_fft --store_cov_diag\
  --vis_units Jy --cov_model empirical_pspec --overwrite\
  --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
  --Jy2mK --beam ${beam_file} --interleave_times --sampling\
  --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}\
  --taper bh


  # power spectra of data with the foregrounds and xtalk retained -- to estimate signal loss from xtalk filter.
  even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_filled.${data_ext}
  odd_file=${even_file/even/odd}
  output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.uvp

  echo pspec_run.py --allow_fft --store_cov_diag\
   --vis_units Jy --cov_model empirical_pspec --overwrite\
   --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
   --Jy2mK --beam ${beam_file} --interleave_times --sampling\
   --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}\
   --taper bh

  pspec_run.py --allow_fft --store_cov_diag\
    --vis_units Jy --cov_model empirical_pspec --overwrite\
    --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
    --Jy2mK --beam ${beam_file} --interleave_times --sampling\
    --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}\
    --taper bh


    # power spectra of data with the foregrounds and no xtalk but also with dayenu filter so that
    # we effectively get no foregrounds or cross-talk (should be same as first case) but we also get accurate window functions.
    # this isn't ready yet because we don't yet have a streamlined way of setting dayenu filter parameters.
    # COMMENT OUT FOR NOW!

    #even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_res.${data_ext}
    #odd_file=${even_file/even/odd}
    #output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res_dayenu.uvp

    #echo pspec_run.py --allow_fft --store_cov_diag\
    # --vis_units Jy --cov_model empirical_pspec --overwrite\
    # --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
    # --Jy2mK --beam ${beam_file} --interleave_times --sampling\
    # --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}\
    # --input_data_weight dayenu

    #pspec_run.py --allow_fft --store_cov_diag\
    #  --vis_units Jy --cov_model empirical_pspec --overwrite\
    #  --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
    #  --Jy2mK --beam ${beam_file} --interleave_times --sampling\
    #  --time_avg --file_type uvh5 ${even_file} ${odd_file} ${output}\
    #  --input_data_weight dayenu
    # form power spectra with dayenu filter
