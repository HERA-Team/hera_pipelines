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
# 4 - Nfiles_per_load : Number of sum and diff files to load simultaneously
# 5 - extension: Extension to be appended to the file name.
# 6+ - filenames
crossCut=${1}
deadCut=${2}
Nbls_per_load=${3}
Nfiles_per_load=${4}
extension=${5}
fn1=`basename ${6}`
sum_files="${@:6}"

# get corresponding diff files
diff_files=()
for fn in ${sum_files[@]}; do
    diff_files+=( ${fn%.sum.uvh5}.diff.uvh5 )
done

# run ant_metrics
cmd="ant_metrics_run.py ${sum_files[@]} \
                        --diff_files ${diff_files[@]} \
                        --crossCut ${crossCut} \
                        --deadCut ${deadCut} \
                        --extension ${extension} \
                        --clobber"
if [ ${Nbls_per_load} != "none" ] && [ ${Nbls_per_load} != "None" ]; then
    cmd="$cmd --Nbls_per_load ${Nbls_per_load}"
fi
if [ ${Nfiles_per_load} != "none" ] && [ ${Nfiles_per_load} != "None" ]; then
    cmd="$cmd --Nfiles_per_load ${Nfiles_per_load}"
fi
echo $cmd
$cmd
echo Finished ant_metrics at $(date)

# This has been removed because ant_metrics files are not added to the librarian individually and this errors as a result.
# add metrics to m&c
# for fn in ${sum_files[@]}; do
#     metrics_f=`echo ${fn%.uvh5}${extension}`
#     echo add_qm_metrics.py --type=ant ${metrics_f}
#     add_qm_metrics.py --type=ant ${metrics_f}
#     echo Finished adding ${metrics_f} to the monitor and control database at $(date)
# done
