#! /bin/bash
set -e

# This function runs auto_metrics, which looks for outliers in day-long autocorrelation waterfalls.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - data filename
# 2 - median_round_modz_cut: Round 1 (median-based) cut on antenna modified Z-score.
# 3 - mean_round_modz_cut: Round 2 (mean-based) cut on antenna modified Z-score.
# 4 - edge_cut: Number of channels on either end to flag (i.e. ignore) when looking for antenna outliers.
# 5 - kt_size: Time kernel half-width for RFI flagging.
# 6 - kf_size: Frequency kernel half-width for RFI flagging.
# 7 - sig_init: The number of sigmas above which to flag pixels.
# 8 - sig_adj: The number of sigmas above which to flag pixels
# 9 - chan_thresh_frac: The fraction of flagged times (ignoring completely flagged times) above which to flag a whole channel.
# 10 - upload_to_librarian: global boolean trigger
# 11 - librarian_auto_metrics: boolean trigger for this step
fn="${1}"
median_round_modz_cut="${2}"
mean_round_modz_cut="${3}"
edge_cut="${4}"
kt_size="${5}"
kf_size="${6}"
sig_init="${7}"
sig_adj="${8}"
chan_thresh_frac="${9}"
upload_to_librarian="${10}"
librarian_auto_metrics="${11}"

# generate outfile
metric_outfile=${fn%.uvh5}.auto_metrics.h5

# get all autos files
jd=$(get_jd ${fn})
decimal_jd=$(get_jd ${fn})
raw_auto_file=${fn%.uvh5}.autos.uvh5
raw_auto_files=zen.${jd}*${raw_auto_file#zen.${decimal_jd}}

# run script
cmd="auto_metrics.py --median_round_modz_cut ${median_round_modz_cut} \
                     --mean_round_modz_cut ${mean_round_modz_cut} \
                     --edge_cut ${edge_cut} \
                     --kt_size ${kt_size} \
                     --kf_size ${kf_size} \
                     --sig_init ${sig_init} \
                     --sig_adj ${sig_adj} \
                     --chan_thresh_frac ${chan_thresh_frac} \
                     ${metric_outfile} ${raw_auto_files}"
echo $cmd
$cmd

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_auto_metrics}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn})

        echo librarian upload local-rtp ${metric_outfile} ${jd}/${metric_outfile}
        librarian upload local-rtp ${metric_outfile} ${jd}/${metric_outfile}
    fi
fi
