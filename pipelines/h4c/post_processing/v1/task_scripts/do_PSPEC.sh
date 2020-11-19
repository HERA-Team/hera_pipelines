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
# 8 - specify external flags to compute more accurate window functions (since )
# 9 - use external flags to generate more accurate window functions.
# large increase in runtime and memory use if flags not separable.
# define input arguments
fn="${1}"
data_ext="${2}"
label="${3}"
beam_file="${4}"
nspw="${5}"
standoff="${6}"
suppression="${7}"
flag_ext="${8}"
jd=$(get_jd $fn)
int_jd=${jd:0:7}
even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_noforegrounds_res.${data_ext}
odd_file=${even_file/even/odd}
output=zen.${jd}.${label}.xtalk_filtered_waterfall_noforegrounds_res.uvp
# form power spectrum between even and odd data sets with offset times.
tfile=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_filled.tavg.${data_ext}

if [ -e "${tfile}" ]
then
    # power spectra of data with the foregrounds and xtalk retained -- to estimate signal loss from xtalk filter.
    even_file=zen.${jd}.even.${label}.waterfall_withforegrounds.${data_ext}
    odd_file=${even_file/even/odd}
    output=zen.${jd}.${label}.waterfall_withforegrounds.pspec.h5
    # average all times incoherently
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw} #--store_window


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels --Nspws ${nspw} #--store_window

    output=zen.${jd}.${label}.waterfall_withforegrounds.fullband.pspec.h5
   # do full subband power spectra.
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels #--store_window


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels #--store_window

    # now do coherently averaged files.
    even_file=zen.${jd}.even.${label}.waterfall_withforegrounds.tavg.${data_ext}
    odd_file=${even_file/even/odd}
    output=zen.${jd}.${label}.waterfall_withforegrounds.tavg.pspec.h5

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


     output=zen.${jd}.${label}.waterfall_withforegrounds.fullband.tavg.fullband.pspec.h5
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
    even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds.${data_ext}
    odd_file=${even_file/even/odd}
    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds.pspec.h5

    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw} #--store_window


    pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels --Nspws ${nspw} #--store_window


    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds.fullband.pspec.h5
   # do full subband power spectra.
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --time_avg --file_type uvh5 --include_autocorrs\
      --taper bh --exclude_flagged_edge_channels #--store_window


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --time_avg --file_type uvh5 --include_autocorrs\
       --taper bh --exclude_flagged_edge_channels #--store_window

       even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.${data_ext}
       odd_file=${even_file/even/odd}
       output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.pspec.h5

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


        output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.fullband.pspec.h5
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


    # now do tavg waterfall.
    external_flags=zen.${jd}.${label}.flags.tavg.h5
    even_file=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.${data_ext}
    odd_file=${even_file/even/odd}
    output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds.day.pspec.h5

    # three spectral windows. Store dayenu window functions and average in time.
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --file_type uvh5 --include_autocorrs\
      --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression} --external_flags ${external_flags}\
      --exclude_flagged_edge_channels --Nspws ${nspw}\
      --store_window --time_avg --store_cov


    pspec_run.py pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --file_type uvh5 --include_autocorrs\
      --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression} --external_flags ${external_flags}\
      --exclude_flagged_edge_channels --Nspws ${nspw}\
      --store_window --time_avg --store_cov


     output=zen.${jd}.${label}.xtalk_filtered_waterfall_withforegrounds.day.tavg.fullband.pspec.h5
     # do full subband power spectra. Store window functions.
     echo pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --interleave_times --sampling\
       --file_type uvh5 --include_autocorrs\
       --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression} --external_flags ${external_flags}\
       --exclude_flagged_edge_channels --store_window --time_avg --store_cov



      pspec_run.py ${even_file} ${odd_file} ${output}\
        --allow_fft --store_cov_diag --Jy2mK_avg\
        --vis_units Jy --cov_model empirical_pspec --overwrite\
        --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
        --Jy2mK --beam ${beam_file} --interleave_times --sampling\
        --file_type uvh5 --include_autocorrs\
        --input_data_weight dayenu --standoff ${standoff} --suppression_factor ${suppression} --external_flags ${external_flags}\
        --exclude_flagged_edge_channels  --store_window --time_avg --store_cov


# Just make power spectra of filled autos.
 auto_file_even=zen.${jd}.even.${label}.auto.foreground_filled.tavg.uvh5
 if [ -e "${auto_file_even}" ]
 then
   auto_file_odd=${auto_file_even/even/odd}
   output=zen.${jd}.${label}.auto.tavg.fullband.pspec.h5
   echo pspec_run.py ${auto_file_even} ${auto_file_odd} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --interleave_times --sampling\
     --file_type uvh5 --fullband_filter --include_autocorrs\
     --exclude_flagged_edge_channels --taper bh\
     --external_flags ${external_flags} --exclude_cross_bls


   pspec_run.py ${auto_file_even} ${auto_file_odd} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --interleave_times --sampling\
     --file_type uvh5 --fullband_filter --include_autocorrs\
     --exclude_flagged_edge_channels --taper bh\
     --external_flags ${external_flags} --exclude_cross_bls

   # Now do subbands.
    output=zen.${jd}.${label}.auto.tavg.pspec.h5
    echo pspec_run.py ${auto_file_even} ${auto_file_odd} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --file_type uvh5 --fullband_filter --include_autocorrs\
      --exclude_flagged_edge_channels --Nspws ${nspw} --taper bh\
      --external_flags ${external_flags} --exclude_cross_bls


    pspec_run.py ${auto_file_even} ${auto_file_odd} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0,1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --interleave_times --sampling\
      --file_type uvh5 --fullband_filter --include_autocorrs\
      --exclude_flagged_edge_channels --Nspws ${nspw} --taper bh\
      --external_flags ${external_flags} --exclude_cross_bls
 else
   echo "${auto_file_even} does not exist!"
 fi

else
  echo "${even_file} does not exist!"
fi
