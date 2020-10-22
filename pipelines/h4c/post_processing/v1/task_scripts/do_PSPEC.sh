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
    # power spectra of data with the foregrounds and xtalk retained -- to estimate signal loss from xtalk filter.
    even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_filled.${data_ext}
    odd_file=${even_file/even/odd}
    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.uvp
    # average all times incoherently
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw} --store_window


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels --Nspws ${nspw} --store_window

    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.fullband_ps.uvp
   # do full subband power spectra.
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --store_window


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels --store_window

    # now do coherently averaged files and keep full covariances.
    even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_filled.tavg.${data_ext}
    odd_file=${even_file/even/odd}
    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.tavg.uvp

    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}


   pspec_run.py ${even_file} ${odd_file} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --interleave_times --sampling\
     --file_type uvh5 --include_autocorrs\
     --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}


     output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_filled.fullband_ps.tavg.uvp
     # do full subband power spectra.
     echo pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels


      pspec_run.py ${even_file} ${odd_file} ${output}\
        --allow_fft --store_cov_diag --Jy2mK_avg\
        --vis_units Jy --cov_model empirical_pspec --overwrite\
        --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
        --Jy2mK --beam ${beam_file} --interleave_times --sampling\
        --file_type uvh5 --include_autocorrs\
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
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw} --store_window


    pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw} --store_window


    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.fullband_ps.uvp
   # do full subband power spectra.
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --store_window


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels --store_window

       even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_res.tavg.${data_ext}
       odd_file=${even_file/even/odd}
       output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.tavg.uvp

       echo pspec_run.py ${even_file} ${odd_file} ${output}\
         --allow_fft --store_cov_diag --Jy2mK_avg\
         --vis_units Jy --cov_model empirical_pspec --overwrite\
         --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
         --Jy2mK --beam ${beam_file} --interleave_times --sampling\
         --file_type uvh5 --include_autocorrs\
         --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}


       pspec_run.py ${even_file} ${odd_file} ${output}\
        --allow_fft --store_cov_diag --Jy2mK_avg\
        --vis_units Jy --cov_model empirical_pspec --overwrite\
        --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
        --Jy2mK --beam ${beam_file} --interleave_times --sampling\
        --file_type uvh5 --include_autocorrs\
        --taper bh --exclude_flagged_edge_channels --Nspws ${nspw}


        output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.fullband_ps.tavg.uvp
        # do full subband power spectra.
        echo pspec_run.py ${even_file} ${odd_file} ${output}\
          --allow_fft --store_cov_diag --Jy2mK_avg\
          --vis_units Jy --cov_model empirical_pspec --overwrite\
          --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
          --Jy2mK --beam ${beam_file} --interleave_times --sampling\
          --file_type uvh5 --include_autocorrs\
          --taper bh --exclude_flagged_edge_channels


         pspec_run.py ${even_file} ${odd_file} ${output}\
           --allow_fft --store_cov_diag --Jy2mK_avg\
           --vis_units Jy --cov_model empirical_pspec --overwrite\
           --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
           --Jy2mK --beam ${beam_file} --interleave_times --sampling\
           --file_type uvh5 --include_autocorrs\
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
       --external_flags ${external_flags} --store_window


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
       --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
       --exclude_flagged_edge_channels --Nspws ${nspw}\
       --external_flags ${external_flags} --store_window

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
      --external_flags ${external_flags} --store_window


    pspec_run.py ${even_file} ${odd_file} ${output}\
    --allow_fft --store_cov_diag --Jy2mK_avg\
    --vis_units Jy --cov_model empirical_pspec --overwrite\
    --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
    --Jy2mK --beam ${beam_file} --interleave_times --sampling\
    --time_avg --file_type uvh5 --fullband_filter --include_autocorrs\
    --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression}\
    --exclude_flagged_edge_channels\
    --external_flags ${external_flags} --store_window

    # now do waterfall.
    external_flags=zen.${jd}.${label}.flags.tavg.h5
    even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_res.tavg.${data_ext}
    odd_file=${even_file/even/odd}
    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.tavg.uvp

    # three spectral windows
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --file_type uvh5 --include_autocorrs\
      --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression} --external_flags ${external_flags}\
      --exclude_flagged_edge_channels --Nspws ${nspw}\


    pspec_run.py ${even_file} ${odd_file} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --interleave_times --sampling\
     --file_type uvh5 --include_autocorrs\
     --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression} --external_flags ${external_flags}\
     --exclude_flagged_edge_channels --Nspws ${nspw}\


     output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds_res.day.fullband_ps.tavg.uvp
     # do full subband power spectra.
     echo pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --file_type uvh5 --include_autocorrs\
       --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression} --external_flags ${external_flags}\
       --exclude_flagged_edge_channels


      pspec_run.py ${even_file} ${odd_file} ${output}\
        --allow_fft --store_cov_diag --Jy2mK_avg\
        --vis_units Jy --cov_model empirical_pspec --overwrite\
        --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
        --Jy2mK --beam ${beam_file} --interleave_times --sampling\
        --file_type uvh5 --include_autocorrs\
        --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression} --external_flags ${external_flags}\
        --exclude_flagged_edge_channels


# Just make power spectra of filled autos.
 auto_file_even=zen.${jd}.even.${label}.foreground_filtered_waterfall_filled.auto.tavg.uvh5
 auto_file_odd=${auto_file_even/even/odd}
 output=zen.${jd}.${label}.auto.fullband_ps.tavg.uvp
 echo pspec_run.py ${auto_file_even} ${auto_file_odd} ${output}\
   --allow_fft --store_cov_diag --Jy2mK_avg\
   --vis_units Jy --cov_model empirical_pspec --overwrite\
   --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
   --Jy2mK --beam ${beam_file} --interleave_times --sampling\
   --file_type uvh5 --fullband_filter --include_autocorrs\
   --exclude_flagged_edge_channels\
   --external_flags ${external_flags}


 pspec_run.py ${auto_file_even} ${auto_file_odd} ${output}\
   --allow_fft --store_cov_diag --Jy2mK_avg\
   --vis_units Jy --cov_model empirical_pspec --overwrite\
   --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
   --Jy2mK --beam ${beam_file} --interleave_times --sampling\
   --file_type uvh5 --fullband_filter --include_autocorrs\
   --exclude_flagged_edge_channels\
   --external_flags ${external_flags}

   # Now do subbands.
    auto_file_even=zen.${jd}.even.${label}.foreground_filtered_waterfall_filled.auto.tavg.uvh5
    auto_file_odd=${auto_file_even/even/odd}
    output=zen.${jd}.${label}.auto.tavg.uvp
    echo pspec_run.py ${auto_file_even} ${auto_file_odd} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --file_type uvh5 --fullband_filter --include_autocorrs\
      --exclude_flagged_edge_channels --Nspws ${nspw}\
      --external_flags ${external_flags}


    pspec_run.py ${auto_file_even} ${auto_file_odd} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --file_type uvh5 --fullband_filter --include_autocorrs\
      --exclude_flagged_edge_channels --Nspws ${nspw}\
      --external_flags ${external_flags}



else
  echo "${even_file} does not exist!"
fi
