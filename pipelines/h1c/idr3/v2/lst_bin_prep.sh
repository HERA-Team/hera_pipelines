#! /bin/bash
# Make smooth_calibrated data files for LST-binning.
#
# Positional arguments:
# 1 - epoch (range of JDs to run)
# 2 - root directory to start from
# 3 - path to .toml file defining workflow (assumed to be in makeflow dir)
# 4 - conda environment to activate for librarian staging and makeflow execution
# 5 - number of concurrent tasks to run for makeflow

epoch="${1}"
root_dir="${2}"
toml_path="${3}"
conda_env="${4}"
ntasks="${5}"

# define the list of JDs to process
if [ "$epoch" == 0 ]; then
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
        "2458061"
        "2458062"
        "2458063"
        "2458064"
        "2458065"
        "2458066"
        "2458067"
        "2458068"
        "2458069"
        "2458070"
        "2458071"
        "2458072"
        )
elif [ "$epoch" == 1 ]; then
    declare -a jdArray=(
        "2458081"
        "2458083"
        "2458084"
        "2458085"
        "2458086"
        "2458087"
        "2458088"
        "2458089"
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
    )
elif [ "$epoch" == 2 ]; then
    declare -a jdArray=(
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
        "2458161"
    )
elif [ "$epoch" == 3 ]; then
    declare -a jdArray=(
        "2458172" # epoch 3
        "2458173" # epoch 3
        "2458185" # epoch 3
        "2458187" # epoch 3
        "2458188" # epoch 3
        "2458189" # epoch 3
        "2458190" # epoch 3
        "2458192" # epoch 3
        "2458195" # epoch 3
        "2458196" # epoch 3
        "2458197" # epoch 3
        "2458198" # epoch 3
        "2458199" # epoch 3
        "2458200" # epoch 3
        "2458201" # epoch 3
        "2458202" # epoch 3
        "2458203" # epoch 3
        "2458204" # epoch 3
        "2458205" # epoch 3
        "2458206" # epoch 3
        "2458207" # epoch 3
        "2458208" # epoch 3
    )
else
    echo Unrecognized epoch $epoch
    exit 1
fi

source ~/.bashrc
conda activate $conda_env

makeflow_dir=`dirname $toml_path`
run_script_dir=`dirname "$0"`
run_script_dir=`realpath "${run_script_dir}"`

for jd in ${jdArray[@]}; do
    # make folder for raw data and makeflow scripts
    date
    cd $makeflow_dir

    mkdir -p lst_bin_prep_$jd
    workdir=`realpath lst_bin_prep_$jd`
    cd lst_bin_prep_$jd
    
    # download raw miriad files
    json_string='{"name-matches": "zen.'"$jd"'.%.HH.uv"}'
    echo librarian stage-files -w local $root_dir "$json_string"
    librarian stage-files -w local $root_dir "$json_string"

    # bring over any missing files
    echo scp -r heramgr@herastore01:/export/hera/herastore01-12/site_transfer/${jd}/zen.${jd}.?????.??.HH.uv $root_dir/$jd
    scp -r heramgr@herastore01:/export/hera/herastore01-12/site_transfer/${jd}/zen.${jd}.?????.??.HH.uv $root_dir/$jd

    # remove miriad files with no corresponding calfits file
    for miriad_file in $root_dir/${jd}/zen.${jd}.?????.xx.HH.uv; do
        sc_file=${miriad_file%.xx.HH.uv}.sum.smooth_abs.calfits
        if [ -f "$sc_file" ]; then
            echo $sc_file exists
        else
            echo Cannot find ${sc_file}, removing ${miriad_file}.
        fi
    done

    # build makeflow 
    echo build_makeflow_from_config.py -c $toml_path $root_dir/${jd}/zen.${jd}.?????.xx.HH.uv
    build_makeflow_from_config.py -c $toml_path $root_dir/${jd}/zen.${jd}.?????.xx.HH.uv

    # run makeflow (builds uvh5 files and then calibrates them)
    mf_file=`realpath *.mf`
    echo makeflow_nrao.sh ${mf_file} ${ntasks}
    makeflow_nrao.sh ${mf_file} ${ntasks}

    # remove unused files
    rm -rf ${root_dir}/${jd}/zen.${jd}.?????.??.HH.uv
    rm -rf ${root_dir}/${jd}/zen.${jd}.?????.sum.uvh5
done
