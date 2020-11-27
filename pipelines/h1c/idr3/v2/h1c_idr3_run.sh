#! /bin/bash
# This is h1c_idr3_run.sh
# For each day in the list of JDs, make a working directory,
# invoke build_h1c_idr3_makeflow.sh (assumed to be in the same directory
# as this script) for that day (which stages files
# and launches the workflow), and then either moves onto the next
# day in the case of success or notifies the user in the case of
# failure.
#
# Positional arguments:
# 1 - root directory to start from
# 2 - path to .toml file defining workflow
# 3 - conda environment to activate for librarian staging and makeflow execution
# 4 - number of concurrent tasks to run for makeflow

root_dir="${1}"
toml_path="${2}"
conda_env="${3}"
ntasks="${4}"

# define the list of JDs to process
declare -a jdArray=(
    "2458041"
    "2458190"
)

makeflow_dir=`dirname $toml_path`
run_script_dir=`dirname "$0"`
run_script_dir=`realpath "${run_script_dir}"`

for jd in ${jdArray[@]}; do
    # make folder for raw data and makeflow scripts
    cd $root_dir
    mkdir -p $jd
    cd $makeflow_dir
    mkdir -p $jd
    workdir=`realpath $jd`
    cd $jd

    # call child script
    echo ${run_script_dir}/make_h1c_idr3_makeflow.sh $jd $root_dir $workdir $toml_path $conda_env $ntasks
    ${run_script_dir}/make_h1c_idr3_makeflow.sh $jd $root_dir $workdir $toml_path $conda_env $ntasks
    # wait for the workflow to finish one way or the other
    while [[ ! -f "succeeded.out" && ! -f "failed.out" ]]; do
        sleep 60;
        echo -n .
    done
    if [ -f "failed.out" ]; then
        echo | mailx -s "idr3_failed on JD $jd" jsdillon@berkeley.edu
        exit 1
    fi
    echo Finished $jd
done
