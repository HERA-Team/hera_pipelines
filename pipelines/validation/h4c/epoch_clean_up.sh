#! /bin/bash
# Make smooth_calibrated data files for LST-binning.
#
# Positional arguments:
# 1 - epoch (range of JDs to run)

epoch="${1}"

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
        "2458062"
        "2458063"
        "2458064"
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
    )
elif [ "$epoch" == 3 ]; then
    declare -a jdArray=(
        "2458185"
        "2458187"
        "2458188"
        "2458189"
        "2458190"
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
else
    echo Unrecognized epoch $epoch
    exit 1
fi

for jd in ${jdArray[@]}; do
    if [[ "${jd}" == "2458041" ]]; then
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.abs.calfits
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.first.calfits
    else
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.abs.calfits
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.autos.uvh5
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.first.calfits
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.flagged_abs.calfits
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.omni.calfits
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.omni_vis.uvh5
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.smooth_calibrated.uvh5
        rm -rf /lustre/aoc/projects/hera/Validation/test-4.1.0/${jd}/*.sum.uvh5
    fi
done
