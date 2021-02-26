#! /bin/bash
set -e

# This function runs auto_metrics, which looks for outliers in day-long autocorrelation waterfalls.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - median_round_modz_cut: Round 1 (median-based) cut on antenna modified Z-score.
# 2 - mean_round_modz_cut: Round 2 (mean-based) cut on antenna modified Z-score.
# 3 - edge_cut: Number of channels on either end to flag (i.e. ignore) when looking for antenna outliers.
# 4 - kt_size: Time kernel half-width for RFI flagging.
# 5 - kf_size: Frequency kernel half-width for RFI flagging.
# 6 - sig_init: The number of sigmas above which to flag pixels.
# 7 - sig_adj: The number of sigmas above which to flag pixels
# 8 - chan_thresh_frac: The fraction of flagged times (ignoring completely flagged times) above which to flag a whole channel.
# 9 - upload_to_librarian: global boolean trigger
# 10 - librarian_auto_metrics: boolean trigger for this step
# 11+ - filenames
median_round_modz_cut="${1}"
mean_round_modz_cut="${2}"
edge_cut="${3}"
kt_size="${4}"
kf_size="${5}"
sig_init="${6}"
sig_adj="${7}"
chan_thresh_frac="${8}"
upload_to_librarian="${9}"
librarian_auto_metrics="${10}"
fn0="${11}"
data_files="${@:11}"

# generate outfile
metric_outfile=${fn0%.uvh5}.auto_metrics.h5

# get all autos files
raw_auto_files=()
for fn in ${data_files[@]}; do
    raw_auto_files+=( ${fn%.uvh5}.autos.uvh5 )
done

# run script
cmd="auto_metrics_run.py --median_round_modz_cut ${median_round_modz_cut} \
                         --mean_round_modz_cut ${mean_round_modz_cut} \
                         --edge_cut ${edge_cut} \
                         --Kt ${kt_size} \
                         --Kf ${kf_size} \
                         --sig_init ${sig_init} \
                         --sig_adj ${sig_adj} \
                         --chan_thresh_frac ${chan_thresh_frac} \
                         --clobber \
                         ${metric_outfile} ${raw_auto_files[@]}"
echo $cmd
$cmd

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_auto_metrics}" == "True" ]; then
        # get the integer portion of the JD
        jd=$(get_int_jd ${fn0})

        echo librarian upload local-rtp ${metric_outfile} ${jd}/${metric_outfile}
        librarian upload local-rtp ${metric_outfile} ${jd}/${metric_outfile}
    fi
fi
