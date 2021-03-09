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
grpstr="${9}"

lst=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`

# form power spectrum between even and odd data sets with offset times.
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  data_ext0=${data_ext/.uvh5/.0.uvh5}
  data_ext1=${data_ext/.uvh5/.1.uvh5}
  #power spectra of data with the foregrounds and xtalk retained -- to estimate signal loss from xtalk filter.
  even_file=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.waterfall.tavg.${data_ext0}
  odd_file=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.waterfall.tavg.${data_ext1}
  if [ -e "${even_file}" ]
  then
      output=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.waterfall.tavg.fullband.pspec.h5
      # average all times incoherently
      echo pspec_run.py ${even_file} ${odd_file} ${output}\
        --allow_fft --store_cov_diag \
        --vis_units Jy --cov_model empirical_pspec --overwrite\
        --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
        --Jy2mK --beam ${beam_file} --sampling\
        --file_type uvh5 \
        --taper bh --truncate_taper


       pspec_run.py ${even_file} ${odd_file} ${output}\
         --allow_fft --store_cov_diag \
         --vis_units Jy --cov_model empirical_pspec --overwrite\
         --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
         --Jy2mK --beam ${beam_file} --sampling\
         --file_type uvh5 \
         --taper bh --truncate_taper

       # do subbands
       output=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.waterfall.tavg.pspec.h5
       echo pspec_run.py ${even_file} ${odd_file} ${output}\
         --allow_fft --store_cov_diag \
         --vis_units Jy --cov_model empirical_pspec --overwrite\
         --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
         --Jy2mK --beam ${beam_file} --sampling\
         --file_type uvh5 --Nspws ${nspw} \
         --taper bh --truncate_taper


        pspec_run.py ${even_file} ${odd_file} ${output}\
          --allow_fft --store_cov_diag \
          --vis_units Jy --cov_model empirical_pspec --overwrite\
          --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
          --Jy2mK --beam ${beam_file} --sampling\
          --file_type uvh5 --Nspws ${nspw} \
          --taper bh --truncate_taper
    else
      echo "${even_file} does not exist!"
    fi

  auto_file=zen.${grpstr}.LST.${lst}.${sd}.${label}.auto.foreground_filled.waterfall.tavg.uvh5
  if [ -e "${auto_file}" ]
  then
   output=zen.${grpstr}.LST.${lst}.${sd}.${label}.auto.waterfall.tavg.fullband.pspec.h5
   echo pspec_run.py ${auto_file} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --sampling\
     --file_type uvh5 --fullband_filter --include_autocorrs\
     --truncate_taper --taper bh\
     --exclude_cross_bls --interleave_times


   pspec_run.py ${auto_file} ${output}\
     --allow_fft --store_cov_diag --Jy2mK_avg\
     --vis_units Jy --cov_model empirical_pspec --overwrite\
     --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn'\
     --Jy2mK --beam ${beam_file} --sampling\
     --file_type uvh5 --fullband_filter --include_autocorrs\
     --truncate_taper --taper bh\
     --exclude_cross_bls --interleave_times

  else
     echo "${auto_file} does not exist!"
  fi
done
