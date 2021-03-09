#! /bin/bash
set -e
export TMPDIR=/lustre/aoc/projects/hera/heramgr/tmp/

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
grpstr="${6}"

lst=`echo ${fn} | sed -r 's/^.*LST.//' | sed -r 's/.sum.*//'`


# form power spectrum between even and odd data sets with offset times.
sumdiff=("sum" "diff")
for sd in ${sumdiff[@]}
do
  #power spectra of data with the foregrounds and xtalk retained -- to estimate signal loss from xtalk filter.
  input=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.tavg.uvh5
  output=zen.${jd}.${sd}.${label}.xtalk_filtered.tavg.fullband.pspec.h5
  if [ -e "${input}" ]
  then
      # average all times incoherently
      echo pspec_run.py ${input} ${output}\
        --allow_fft --store_cov_diag \
        --vis_units Jy --cov_model empirical_pspec --overwrite\
        --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
        --Jy2mK --beam ${beam_file} --sampling\
        --file_type uvh5 --avg_redundant --exclude_auto_bls\
        --taper bh --exclude_flagged_edge_channels


       pspec_run.py ${input} ${output}\
         --allow_fft --store_cov_diag \
         --vis_units Jy --cov_model empirical_pspec --overwrite\
         --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
         --Jy2mK --beam ${beam_file} --sampling\
         --file_type uvh5 --avg_redundant --exclude_auto_bls\
         --taper bh --exclude_flagged_edge_channels

       # do subbands
       output=zen.${grpstr}.LST.${lst}.${sd}.${label}.xtalk_filtered.tavg.pspec.h5
       echo pspec_run.py ${input} ${output}\
         --allow_fft --store_cov_diag \
         --vis_units Jy --cov_model empirical_pspec --overwrite\
         --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
         --Jy2mK --beam ${beam_file} --sampling\
         --file_type uvh5 --Nspws ${nspw} --avg_redundant\
         --taper bh --exclude_flagged_edge_channels --exclude_auto_bls


        pspec_run.py ${input} ${output}\
          --allow_fft --store_cov_diag \
          --vis_units Jy --cov_model empirical_pspec --overwrite\
          --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
          --Jy2mK --beam ${beam_file} --sampling\
          --file_type uvh5 --Nspws ${nspw} --avg_redundant\
          --taper bh --exclude_flagged_edge_channels --exclude_auto_bls
    else
      echo "${even_file} does not exist!"
    fi

    input=zen.${grpstr}.LST.${lst}.${sd}.${label}.waterfall.tavg.uvh5
    output=zen.${grpstr}.LST.${lst}.${sd}.${label}.waterfall.tavg.fullband.pspec.h5
    if [ -e "${input}" ]
    then
        # average all times incoherently
        echo pspec_run.py ${input} ${output}\
          --allow_fft --store_cov_diag \
          --vis_units Jy --cov_model empirical_pspec --overwrite\
          --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
          --Jy2mK --beam ${beam_file} --sampling\
          --file_type uvh5 --exclude_auto_bls --avg_redundant\
          --taper bh --exclude_flagged_edge_channels


         pspec_run.py ${input} ${output}\
           --allow_fft --store_cov_diag \
           --vis_units Jy --cov_model empirical_pspec --overwrite\
           --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
           --Jy2mK --beam ${beam_file} --sampling\
           --file_type uvh5 --exclude_auto_bls --avg_redundant\
           --taper bh --exclude_flagged_edge_channels

         # do subbands
         output=zen.${jd}.${sd}.${label}.waterfall.tavg.pspec.h5
         echo pspec_run.py ${input} ${output}\
           --allow_fft --store_cov_diag \
           --vis_units Jy --cov_model empirical_pspec --overwrite\
           --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
           --Jy2mK --beam ${beam_file} --sampling\
           --file_type uvh5 --Nspws ${nspw} --exclude_auto_bls --avg_redundant\
           --taper bh --exclude_flagged_edge_channels


          pspec_run.py ${input} ${output}\
            --allow_fft --store_cov_diag \
            --vis_units Jy --cov_model empirical_pspec --overwrite\
            --dset_pairs '0 1' --pol_pairs 'ee ee, nn nn, pI pI, pQ pQ'\
            --Jy2mK --beam ${beam_file} --sampling\
            --file_type uvh5 --Nspws ${nspw} --exclude_auto_bls --avg_redundant\
            --taper bh --exclude_flagged_edge_channels

  else
      echo "${even_file} does not exist!"
  fi
 auto_file=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.tavg.uvh5

  if [ -e "${auto_file}" ]
  then
   output=zen.${grpstr}.LST.${lst}.${sd}.${label}.autos.tavg.fullband.pspec.h5
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
     echo "${auto_file} does not exist!"
  fi
done
