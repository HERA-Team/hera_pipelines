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
# Build all the cold-storage bundles for post-inpaint intermediates
# --------------------------------------------------------------------

# pI delay-filtered SNR notebooks and data (produced without FRF)
make_tar "single_baseline_files/${jd}_single_baseline_pI_SNR_notebooks.tar.gz" \
         single_baseline_files/zen.${jd}.baseline.*.sum.single_baseline_pI_SNR.html
make_tar "single_baseline_files/${jd}_pI_DLYFILT_SNRs.tar.gz" \
         single_baseline_files/zen.${jd}.baseline.*.sum.smooth_calibrated.red_avg.inpainted.pI_DLYFILT_SNR.uvh5

# pI FRF SNR notebooks and data (produced with FRF)
make_tar "single_baseline_files/${jd}_single_baseline_pI_FRF_SNR_notebooks.tar.gz" \
         single_baseline_files/zen.${jd}.baseline.*.sum.single_baseline_pI_FRF_SNR.html
make_tar "single_baseline_files/${jd}_pI_FRF_SNRs.tar.gz" \
         single_baseline_files/zen.${jd}.baseline.*.sum.smooth_calibrated.red_avg.inpainted.pI_FRF_SNR.uvh5

# reinpaint notebooks
make_tar "single_baseline_files/${jd}_single_baseline_reinpaint_notebooks.tar.gz" \
         single_baseline_files/zen.${jd}.baseline.*.sum.single_baseline_scaffolded_and_feathered_inpainter.html

echo "All post-inpaint archives created and verified (>1 MiB each)."
