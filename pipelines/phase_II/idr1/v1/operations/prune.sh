#! /bin/bash
set -e

# Once a night has been reviewed and approved: deletes what the makeflow's CLEANUP step bundled for cold storage,
# and what isn't worth keeping (the raw data among it), leaving the rest (the final products) on Lustre. What goes
# where is up to each product's retention in the toml's [DATA_PRODUCTS]: "archive" ones were bundled by CLEANUP,
# so their files are deleted here; "delete" ones are deleted here outright; "keep" ones are left alone. Nothing is
# copied to cold storage here (that is archive.sh, next), and every part can be rerun safely.
# usage: prune.sh <JD> <pipeline toml>

source "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/operations/scripts/common.sh" "$1"
toml=${2:?usage: prune.sh <JD> <pipeline toml>}
require_approved
# the pipeline's own helpers (get_products, get_product_files, get_filename, ...), which read its [DATA_PRODUCTS]
source "$(dirname "${toml}")/task_scripts/_common.sh"
sb_dir=$(dirname "$(get_filename "${toml}" CORNER_TURN_MAP)")  # where the single-baseline files are

####################################
# 1. the makeflow folder, as in H6C
####################################

cd "${MAKEFLOW_DIR}"
# (its .out is bundled below, so on a rerun it is found in that bundle's list)
if ! compgen -G "*.CLEANUP.out" > /dev/null && ! grep -qs '\.CLEANUP\.out$' makeflow_outs.tar.gz.contents.txt; then
    die "the makeflow's CLEANUP job never finished in ${MAKEFLOW_DIR}, so the night's bundles aren't all there"
fi
pack_makeflow_folder "${toml}"

##########################################################
# 2. the files the makeflow's CLEANUP step bundled up
##########################################################

cd "${NIGHT_DIR}"
shopt -s nullglob
contents=(${JD}_*.tar.gz.contents.txt ${sb_dir}/${JD}_*.tar.gz.contents.txt)  # these stay here once archived
shopt -u nullglob
(( ${#contents[@]} )) || die "no ${JD}_*.tar.gz bundles in ${NIGHT_DIR} or ${NIGHT_DIR}/${sb_dir}"
for list in "${contents[@]}"; do
    delete_bundled "${list%.contents.txt}"
done

################################################################################################
# 3. the products with retention = "delete": the raw data (the sum and diff files, which the
#    librarian keeps), and what is large and remade from them. From the night's folder, where the
#    raw data are links, and from {raw_root}/{JD}/, where they were staged.
################################################################################################

function delete_product ()
# delete_product <product> <folder>: delete the product's files from the folder (if there is one), saying how many
{
    [[ -d "$2" ]] || return 0
    local files
    files=$(cd "$2" && get_product_files "${toml}" "${JD}" "$1")
    if [[ -n "${files}" ]]; then
        (cd "$2" && echo "${files}" | xargs rm -f)
        echo "Deleted $(echo "${files}" | wc -l | tr -d ' ') $1 files from $2"
    fi
}

deleted=$(get_products "${toml}" delete)
for product in ${deleted}; do
    delete_product "${product}" "${NIGHT_DIR}"
    delete_product "${product}" "${RAW_DIR}"
done
if [[ -d "${RAW_DIR}" ]]; then
    rmdir "${RAW_DIR}" 2> /dev/null || echo "WARNING: left ${RAW_DIR} in place: it still holds other files"
fi

###################################################################
# 4. what's left: the final products, and the bundles for archive.sh
###################################################################

# Anything [DATA_PRODUCTS] doesn't declare is kept, and archive.sh copies it to cold storage with the rest. Say so,
# so that a file the pipeline makes without an entry there doesn't go unnoticed.
undeclared=$(get_undeclared_files "${toml}" "${JD}" "${JD}_*.tar.gz*" "${sb_dir}/${JD}_*.tar.gz*" COLD_STORAGE_INFO.txt)
if [[ -n "${undeclared}" ]]; then
    echo "WARNING: $(echo "${undeclared}" | wc -l | tr -d ' ') files here aren't in [DATA_PRODUCTS] (so they are kept, and archived):"
    echo "${undeclared}" | sed -n '1,20p'
fi
echo "Pruned ${JD} at $(date). ${NIGHT_DIR} now holds $(du -sh "${NIGHT_DIR}" | cut -f1)."
