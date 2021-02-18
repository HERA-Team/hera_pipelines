#! /bin/bash
set -e

# This function runs atennna metrics on all antennas

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - crossCut: Metric cut for most cross-polarized antenna.
# 2 - deadCut: Metric cut for most likely dead antenna.
# 3 - Nbls_per_load: Number of baselines to load simultaneously.
# 4 - extension: Extension to be appended to the file name.
# 5 - upload_to_librarian: global boolean trigger
# 6 - librarian_ant_metrics: boolean trigger for this step
# 7+ - filenames
crossCut=${1}
deadCut=${2}
Nbls_per_load=${3}
extension=${4}
upload_to_librarian="${5}"
librarian_ant_metrics="${6}"
fn1=`basename ${7}`
sum_files="${@:7}"

diff_files=()
for fn in ${sum_files[@]}; do
    diff_files+=( ${fn%.sum.uvh5}.diff.uvh5 )
done

# We only want to run ant metrics on sum files
echo ant_metrics_run.py ${sum_files[@]} --diff_files ${diff_files[@]} --crossCut ${crossCut} --deadCut ${deadCut} --extension ${extension} --Nbls_per_load ${Nbls_per_load} --clobber
ant_metrics_run.py ${sum_files[@]} --diff_files ${diff_files[@]} --crossCut ${crossCut} --deadCut ${deadCut} --extension ${extension} --Nbls_per_load ${Nbls_per_load} --clobber

# upload results to librarian if desired
if [ "${upload_to_librarian}" == "True" ]; then
    if [ "${librarian_ant_metrics}" == "True" ]; then
        for fn in ${sum_files[@]}; do

            # get the integer portion of the JD
            bn=`basename ${fn}`
            jd=$(get_int_jd ${bn})

            # get ant_metrics file
            metrics_f=`echo ${fn%.uvh5}${extension}`
            metrics_out=`echo ${bn%.uvh5}${extension}`

            echo librarian upload local-rtp ${metrics_f} ${jd}/${metrics_out}
            librarian upload local-rtp ${metrics_f} ${jd}/${metrics_out}
        done
    fi
fi
