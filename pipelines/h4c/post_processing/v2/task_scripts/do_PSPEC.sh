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
tfile=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds.tavg.${data_ext}
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
if [ -e "${tfile}" ]
then
  data_ext0=${data_ext/.uvh5/.0.uvh5}
  data_ext1=${data_ext/.uvh5/.0.uvh5}
  #power spectra of data with the foregrounds and xtalk retained -- to estimate signal loss from xtalk filter.
  even_file=zen.${jd}.${sd}.${label}.xtalk_filtered_waterfall.tavg.${data_ext0}
  odd_file=zen.${jd}.${sd}.${label}.xtalk_filtered_waterfall.tavg.${data_ext1}
  output=zen.${jd}.${sd}.${label}.xtalk_filtered_waterfall.tavg.fullband.pspec.h5
    # average all times incoherently
    echo pspec_run.py ${even_file} ${odd_file} ${output}\
      --allow_fft --store_cov_diag --Jy2mK_avg\
      --vis_units Jy --cov_model empirical_pspec --overwrite\
      --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn'\
      --Jy2mK --beam ${beam_file} --sampling\
      --time_avg --file_type uvh5 \
      --taper bh --exclude_flagged_edge_channels


     pspec_run.py ${even_file} ${odd_file} ${output}\
       --allow_fft --store_cov_diag --Jy2mK_avg\
       --vis_units Jy --cov_model empirical_pspec --overwrite\
       --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn'\
       --Jy2mK --beam ${beam_file} --sampling\
       --time_avg --file_type uvh5 \
       --taper bh --exclude_flagged_edge_channels

# Just make power spectra of filled autos.
 auto_file=zen.${jd}.${sd}.${label}.auto.foreground_filled_waterfall.tavg.uvh5
 if [ -e "${auto_file}" ]
 then
   output=zen.${jd}.${sd}.${label}.auto.tavg.fullband.pspec.h5
   echo pspec_run.py ${auto_file} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --sampling\
     --file_type uvh5 --fullband_filter --include_autocorrs\
     --exclude_flagged_edge_channels --taper bh\
     --exclude_cross_bls --interleave_times


   pspec_run.py ${auto_file} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --sampling\
     --file_type uvh5 --fullband_filter --include_autocorrs\
     --exclude_flagged_edge_channels --taper bh\
     --exclude_cross_bls --interleave_times

 else
   echo "${auto_file_even} does not exist!"
 fi

else
  echo "${tfile} does not exist!"
fi
done
