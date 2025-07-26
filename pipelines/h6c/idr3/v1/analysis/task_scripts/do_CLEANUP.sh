#! /bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

jd="$(basename "$(pwd -P)")"

# --------------------------------------------------------------------
# Helper: create archive and verify it exists and is >1 MiB
# --------------------------------------------------------------------
make_tar () {
    local archive=$1; shift         # first arg: name of the .tar.gz to write
    local pattern=("$@")            # remaining args: files to include

    # 1) create the archive
    tar -czvf "${archive}" "${pattern[@]}"

    # 2) verify it exists
    if [[ ! -f "${archive}" ]]; then
        echo "ERROR: ${archive} was not created!" >&2
        exit 1
    fi

    # 3) verify size >1 MiB
    local bytes
    bytes=$(stat --format=%s "${archive}")   # portable: `stat -c%s` on GNU; on macOS use `stat -f%z`
    if (( bytes < 1048576 )); then
        echo "ERROR: ${archive} is only ${bytes} bytes (<1 MiB)" >&2
        exit 1
    fi
}

# --------------------------------------------------------------------
# Build all the cold-storage bundles
# --------------------------------------------------------------------
make_tar "${jd}_ant_metrics.tar.gz"                              zen.${jd}.*.sum.ant_metrics.hdf5
make_tar "${jd}_calibration_notebooks.tar.gz"                    zen.${jd}.*.sum.calibration_notebook.html
make_tar "${jd}_delay_filtered_average_zscore_notebooks.tar.gz"  zen.${jd}.*.sum.delay_filtered_average_zscore_notebook.html
make_tar "${jd}_postprocessing_notebooks.tar.gz"                 zen.${jd}.*.sum.postprocessing_notebook.html
make_tar "${jd}_omni_calfits.tar.gz"                             zen.${jd}.*.sum.omni.calfits
make_tar "${jd}_smooth_calfits.tar.gz"                           zen.${jd}.*.sum.smooth.calfits
make_tar "${jd}_flag_waterfalls.tar.gz"                          zen.${jd}.*.sum.flag_waterfall.h5
make_tar "${jd}_red_avg_zscores.tar.gz"                          zen.${jd}.*.sum.red_avg_zscore.h5
make_tar  "${jd}_avg_abs.tar.gz"                                 zen.${jd}.*.sum.smooth_calibrated.avg_abs_*.uvh5

# single-baseline bundles (keep them inside the sub-dir)
make_tar  "single_baseline_files/${jd}_single_baseline_2D_filtered_SNRs_notebooks.tar.gz" \
          single_baseline_files/zen.${jd}.baseline.*.sum.single_baseline_2D_filtered_SNRs.html
make_tar  "single_baseline_files/${jd}_single_baseline_2D_informed_inpaint_notebooks.tar.gz" \
          single_baseline_files/zen.${jd}.baseline.*.sum.single_baseline_2D_informed_inpaint.html
make_tar  "single_baseline_files/${jd}_2Dfilt_SNRs.tar.gz" \
          single_baseline_files/zen.${jd}.baseline.*.sum.smooth_calibrated.red_avg.2Dfilt_SNR.uvh5

echo "All archives created and verified (>1 MiB each)."
