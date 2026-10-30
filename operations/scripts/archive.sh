#! /bin/bash
set -e

# Once a night has been pruned: copies its folder (the {JD}_*.tar.gz bundles of its intermediate products, and
# whatever else the pipeline keeps there) and its makeflow folder to cold storage, checks the copy, and only then
# deletes the bundles from Lustre. Everything else stays on Lustre, and nothing is ever deleted from cold storage,
# so this can be rerun safely.
# usage: archive.sh <JD>

source "$(dirname "$0")/common.sh" "$1"
require_approved

mkdir -p "${COLD_DIR}/makeflow"
echo "Copying ${NIGHT_DIR} and ${MAKEFLOW_DIR} to ${COLD_DIR} at $(date)"
rsync -a "${NIGHT_DIR}/" "${COLD_DIR}/"
rsync -a "${MAKEFLOW_DIR}/" "${COLD_DIR}/makeflow/"

# check the copy: a second pass that would have nothing left to copy
for pair in "${NIGHT_DIR}/ ${COLD_DIR}/" "${MAKEFLOW_DIR}/ ${COLD_DIR}/makeflow/"; do
    differences=$(rsync -a --dry-run --itemize-changes ${pair})
    [[ -z "${differences}" ]] || die "the copy of ${pair% *} in cold storage differs from it:
${differences}"
done
echo "Checked the copy in ${COLD_DIR}"

# the bundles now live in cold storage; their .contents.txt lists stay here as a record of what each holds
cd "${NIGHT_DIR}"
n_bundles=0
while read -r bundle; do
    [[ -s "${COLD_DIR}/${bundle}" ]] || die "${COLD_DIR}/${bundle} is missing"
    rm -f "${bundle}"
    n_bundles=$(( n_bundles + 1 ))
done < <(find . ! -type d -name "${JD}_*.tar.gz" | sed 's|^\./||')
echo "Deleted ${n_bundles} bundles from ${NIGHT_DIR}, now in cold storage"

echo "The bundles of ${JD}'s intermediate products (${JD}_*.tar.gz), a copy of everything else in this folder, and" \
     "the makeflow folder are archived in ${COLD_DIR}; the .contents.txt files here list what each bundle holds." \
     > COLD_STORAGE_INFO.txt
echo "Archived ${JD} at $(date). ${NIGHT_DIR} now holds $(du -sh "${NIGHT_DIR}" | cut -f1)."
