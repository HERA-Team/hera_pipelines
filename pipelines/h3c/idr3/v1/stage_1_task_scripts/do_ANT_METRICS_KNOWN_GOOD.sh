#! /bin/bash
set -e

# This function runs atennna metrics on just the antennas known to be good apriori

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - crossCut: Modified z-score cut for most cross-polarized antenna.
# 2 - deadCut: Modified z-score cut for most likely dead antenna.
# 3 - Nbls_per_load: Number of baselines to load simultaneously.
# 4 - extension: Extension to be appended to the file name.
# 5 - path_to_analysis_bad_ants: folder containing text files with filename `{JD}.txt` with bad antennas
# 6+ - filenames
crossCut=${1}
deadCut=${2}
Nbls_per_load=${3}
extension=${4}
path_to_analysis_bad_ants=${5}
fn1=`basename ${6}`
data_files="${@:6}"

# get exants from bad ants folder
jd=$(get_jd ${fn1})
jd_int=`echo $jd | awk '{${fn1}=int(${fn1})}1'`

# make filename
bad_ants_fn=`echo "${path_to_analysis_bad_ants}/${jd_int}.txt"`
xants=$(prep_exants ${bad_ants_fn})


# We only want to run ant metrics on sum files
echo ant_metrics_run.py ${data_files} --crossCut ${crossCut} --deadCut ${deadCut} --extension ${extension} --Nbls_per_load ${Nbls_per_load} \
    --clobber --apriori_xants ${xants}
ant_metrics_run.py ${data_files} --crossCut ${crossCut} --deadCut ${deadCut} --extension ${extension} --Nbls_per_load ${Nbls_per_load} \
    --clobber --apriori_xants ${xants}
