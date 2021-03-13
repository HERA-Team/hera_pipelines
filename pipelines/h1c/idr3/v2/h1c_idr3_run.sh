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
# 2 - path to .toml file defining workflow (assumed to be in makeflow dir)
# 3 - conda environment to activate for librarian staging and makeflow execution
# 4 - number of concurrent tasks to run for makeflow

root_dir="${1}"
toml_path="${2}"
conda_env="${3}"
ntasks="${4}"

# define the list of JDs to process
declare -a jdArray=(
    "2458041"
    "2458042"
    "2458043"
    "2458044"
    "2458045"
    "2458046"
    "2458047"
    "2458048"
    "2458049"
    "2458050"
    "2458051"
    "2458052"
    "2458058"
    "2458059"
    "2458062"
    "2458063"
    "2458064"
    "2458067"
    "2458068"
    "2458069"
    "2458070"
    "2458071"
    "2458072"
    "2458081"
    "2458083"
    "2458084"
    "2458085"
    "2458086"
    "2458087"
    "2458088"
    "2458090"
    "2458091"
    "2458092"
    "2458094"
    "2458095"
    "2458096"
    "2458097"
    "2458098"
    "2458099"
    "2458101"
    "2458102"
    "2458103"
    "2458104"
    "2458105"
    "2458106"
    "2458107"
    "2458108"
    "2458109"
    "2458110"
    "2458111"
    "2458112"
    "2458113"
    "2458114"
    "2458115"
    "2458116"
    "2458134"
    "2458135"
    "2458136"
    "2458139"
    "2458140"
    "2458141"
    "2458142"
    "2458143"
    "2458144"
    "2458145"
    "2458146"
    "2458147"
    "2458148"
    "2458149"
    "2458150"
    "2458151"
    "2458153"
    "2458154"
    "2458155"
    "2458157"
    "2458158"
    "2458159"
    "2458185"
    "2458187"
    "2458188"
    "2458189"
    "2458190"
    "2458192"
    "2458195"
    "2458196"
    "2458197"
    "2458198"
    "2458199"
    "2458200"
    "2458201"
    "2458202"
    "2458203"
    "2458204"
    "2458205"
    "2458206"
    "2458207"
    "2458208"
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
    pwd

    # call child script
    echo ${run_script_dir}/build_h1c_idr3_makeflow.sh.sh $jd $root_dir $workdir $toml_path $conda_env $ntasks
    ${run_script_dir}/build_h1c_idr3_makeflow.sh $jd $root_dir $workdir $toml_path $conda_env $ntasks
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
    date
done
