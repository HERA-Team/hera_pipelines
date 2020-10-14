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
# 5 - number of spectral windows to estimate pspec over.
# 6 - delay-buffer beyond wedge in ns
# 7 - suppression factor in foreground filter.
# define input arguments
fn="${1}"
data_ext="${2}"
label="${3}"
beam_file="${4}"
nspw="${5}"
standoff="${6}"
suppression="${7}"
jd=$(get_jd $fn)
int_jd=${jd:0:7}

even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_noforegrounds_res.${data_ext}
odd_file=${even_file/even/odd}
output=zen.${jd}.${label}.xtalk_filtered_waterfall_noforegrounds_res.uvp
# form power spectrum between even and odd data sets with offset times.

if [ -e "${even_file}" ]
then
  # power spectra of data with no foregrounds or xtalk.
  echo pspec_run.py ${even_file} ${odd_file} ${output}\
    --allow_fft --store_cov_diag --Jy2mK_avg\
    --vis_units Jy --cov_model empirical_pspec --overwrite\
    --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
    --Jy2mK --beam ${beam_file} --interleave_times --sampling\
    --time_avg --file_type uvh5 --include_autocorrs\
    --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}


   pspec_run.py ${even_file} ${odd_file} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --interleave_times --sampling\
     --time_avg --file_type uvh5 --include_autocorrs\
     --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}

  output=zen.${jd}.${label}.xtalk_filtered_waterfall_noforegrounds_res.fullband_ps.uvp
  # do full subband power spectra.
   echo pspec_run.py ${even_file} ${odd_file} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --interleave_times --sampling\
     --time_avg --file_type uvh5 --include_autocorrs\
     --taper bh --exclude_flagged_edge_channels


    pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels


    # power spectra of data with the foregrounds and xtalk retained -- to estimate signal loss from xtalk filter.
    even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_filled.${data_ext}
    odd_file=${even_file/even/odd}
    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.uvp

    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}

    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.fullband_ps.uvp
   # do full subband power spectra.
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels

      # power spectra of data with foregrounds but no xtalk.
    even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_res.${data_ext}
    odd_file=${even_file/even/odd}
    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.uvp

    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}


    pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}


    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.fullband_ps.uvp
   # do full subband power spectra.
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels




     # power spectra of data with foregrounds but no xtalk with DAYENU applied.
     # use external roto-flag file.
     external_flags=zen.${int_jd}.${label}.roto_flag.flags.h5
     even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_res.${data_ext}
     odd_file=${even_file/even/odd}
     output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.uvp

     echo pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
       --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
       --exclude_flagged_edge_channels --Nspws ${nspw}\
       --external_flags ${external_flags}


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
       --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
       --exclude_flagged_edge_channels --Nspws ${nspw}\
       --external_flags ${external_flags}

     output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.fullband_ps.uvp
    # do full subband power spectra.
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
      --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
      --exclude_flagged_edge_channels\
      --external_flags ${external_flags}


    pspec_run.py ${even_file} ${odd_file} ${output}\
    --allow_fft --store_cov_diag --Jy2mK_avg\
    --vis_units Jy --cov_model empirical_pspec --overwrite\
    --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
    --Jy2mK --beam ${beam_file} --interleave_times --sampling\
    --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
    --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
    --exclude_flagged_edge_channels\
    --external_flags ${external_flags}

  # try H^-1 norm too
  output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.Hinv.uvp
  echo pspec_run.py ${even_file} ${odd_file} ${output}\
    --allow_fft --store_cov_diag --Jy2mK_avg\
    --vis_units Jy --cov_model empirical_pspec --overwrite\
    --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
    --Jy2mK --beam ${beam_file} --interleave_times --sampling\
    --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
    --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
    --exclude_flagged_edge_channels --Nspws ${nspw} --rcond 1e-17\
    --external_flags ${external_flags} --norm 'H^-1'


  pspec_run.py ${even_file} ${odd_file} ${output}\
    --allow_fft --store_cov_diag --Jy2mK_avg\
    --vis_units Jy --cov_model empirical_pspec --overwrite\
    --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
    --Jy2mK --beam ${beam_file} --interleave_times --sampling\
    --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
    --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
    --exclude_flagged_edge_channels --Nspws ${nspw} --rcond 1e-17\
    --external_flags ${external_flags} --norm 'H^-1'

  output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.Hinv.fullband_ps.uvp
 # do full subband power spectra.
 echo pspec_run.py ${even_file} ${odd_file} ${output}\
   --allow_fft --store_cov_diag --Jy2mK_avg\
   --vis_units Jy --cov_model empirical_pspec --overwrite\
   --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
   --Jy2mK --beam ${beam_file} --interleave_times --sampling\
   --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
   --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
   --exclude_flagged_edge_channels --rcond 1e-17\
   --external_flags ${external_flags} --norm 'H^-1'


 pspec_run.py ${even_file} ${odd_file} ${output}\
 --allow_fft --store_cov_diag --Jy2mK_avg\
 --vis_units Jy --cov_model empirical_pspec --overwrite\
 --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
 --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
 --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
 --exclude_flagged_edge_channels --rcond 1e-17\
 --external_flags ${external_flags} --norm 'H^-1'

 # make auto power spectra with dayenu filter.
 output=zen.${jd}.${label}.auto.day.fullband_ps.uvp
 echo pspec_run.py ${auto_file} ${output}\
   --allow_fft --store_cov_diag --Jy2mK_avg\
   --vis_units Jy --cov_model empirical_pspec --overwrite\
   --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
   --Jy2mK --beam ${beam_file} --interleave_times --sampling\
   --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
   --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
   --exclude_flagged_edge_channels --rcond 1e-17\
   --external_flags ${external_flags}


 pspec_run.py ${auto_file} ${output}\
 --allow_fft --store_cov_diag --Jy2mK_avg\
 --vis_units Jy --cov_model empirical_pspec --overwrite\
 --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
 --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
 --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
 --exclude_flagged_edge_channels --rcond 1e-17\
 --external_flags ${external_flags}


 # AUTO POWER SPECTRA

 # make auto power spectra without dayenu filter. Full band.
 output=zen.${jd}.${label}.auto.fullband_ps.uvp
 echo pspec_run.py ${auto_file} ${output}\
   --allow_fft --store_cov_diag --Jy2mK_avg\
   --vis_units Jy --cov_model empirical_pspec --overwrite\
   --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
   --Jy2mK --beam ${beam_file} --interleave_times --sampling\
   --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
   --exclude_flagged_edge_channels --rcond 1e-17\
   --external_flags ${external_flags}


 pspec_run.py ${auto_file} ${output}\
 --allow_fft --store_cov_diag --Jy2mK_avg\
 --vis_units Jy --cov_model empirical_pspec --overwrite\
 --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
 --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
 --exclude_flagged_edge_channels --rcond 1e-17\
 --external_flags ${external_flags}

 # make auto power spectra with dayenu filter. Fully band.
 output=zen.${jd}.${label}.auto.day.ps.uvp
 echo pspec_run.py ${auto_file} ${output}\
   --allow_fft --store_cov_diag --Jy2mK_avg\
   --vis_units Jy --cov_model empirical_pspec --overwrite\
   --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
   --Jy2mK --beam ${beam_file} --interleave_times --sampling\
   --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
   --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
   --exclude_flagged_edge_channels --rcond 1e-17\
   --external_flags ${external_flags} --Nspws 3


 pspec_run.py ${auto_file} ${output}\
 --allow_fft --store_cov_diag --Jy2mK_avg\
 --vis_units Jy --cov_model empirical_pspec --overwrite\
 --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
 --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
 --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
 --exclude_flagged_edge_channels --rcond 1e-17\
 --external_flags ${external_flags} --Nspws 3


 # make auto power spectra without dayenu filter.
 output=zen.${jd}.${label}.auto.ps.uvp
 echo pspec_run.py ${auto_file} ${output}\
   --allow_fft --store_cov_diag --Jy2mK_avg\
   --vis_units Jy --cov_model empirical_pspec --overwrite\
   --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
   --Jy2mK --beam ${beam_file} --interleave_times --sampling\
   --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
   --exclude_flagged_edge_channels --rcond 1e-17\
   --external_flags ${external_flags} --Nspws 3


 pspec_run.py ${auto_file} ${output}\
 --allow_fft --store_cov_diag --Jy2mK_avg\
 --vis_units Jy --cov_model empirical_pspec --overwrite\
 --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
 --Jy2mK --beam ${beam_file} --interleave_times --sampling\
 --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
 --exclude_flagged_edge_channels --rcond 1e-17\
 --external_flags ${external_flags} --Nspws 3




else
  echo "${even_file} does not exist!"
fi
