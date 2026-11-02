#! /bin/bash
# For the tests and the demo: what Phase II's makeflow would leave in a night's folder, for each raw file and for two
# baselines, as empty files, and then the real do_CLEANUP.sh run on them as makeflow's wrapper would run it.
# The fake makeflow_nrao.sh (operations/tests/fake_bin/) runs this in the night's folder, with its first sum file.
set -e
toml="$(cd "$(dirname "$0")/../../analysis" && pwd)/phase_II_analysis.toml"
jd=$(echo "$1" | cut -d. -f2)

mkdir -p single_baseline_files
for f in zen.${jd}.?????.sum.uvh5; do
    base=${f%.uvh5}
    for suffix in sky_calibration_notebook.html redundant_averaging_notebook.html ant_metrics.hdf5 ant_class.csv \
                  sky.calfits snap_decoherence.h5 red_avg_zscore.h5 flag_waterfall.h5 antenna_flags.h5 smooth.calfits \
                  smooth_calibrated.red_avg.uvh5; do
        echo "${base}.${suffix}" > "${base}.${suffix}"
    done
done
echo "flags" > ${jd}_aposteriori_flags.yaml
for bl in 0_4 1_5; do
    base=single_baseline_files/zen.${jd}.baseline.${bl}.sum
    for suffix in sky_filtered_SNR_notebook.html pI_DLYFILT_SNR_notebook.html pI_FRF_SNR_notebook.html \
                  wiener_inpaint_notebook.html sky_filtered_SNR.uvh5 pI_dlyfilt_SNR.uvh5 pI_FRF_SNR.uvh5 \
                  smooth_calibrated.red_avg.uvh5 inpainted.uvh5 where_inpainted.h5 inpaint_covariance.h5; do
        echo "${base}.${suffix}" > "${base}.${suffix}"
    done
done
echo "map" > single_baseline_files/corner_turn_map.yaml
for round in sky_filtered pI_dlyfilt pI_FRF; do
    echo "flags" > single_baseline_files/zen.${jd}.flag_waterfall_${round}.h5
done
echo "flags" > single_baseline_files/zen.${jd}.3C_286.flag_waterfall_pI_FRF.h5
echo "model" > single_baseline_files/phased.${jd}.3C_286.fg_model.uvh5

bash "$(dirname "${toml}")/task_scripts/do_CLEANUP.sh" "$1" "${toml}"
