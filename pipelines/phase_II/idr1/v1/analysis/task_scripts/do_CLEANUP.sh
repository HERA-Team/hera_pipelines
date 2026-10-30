#! /bin/bash
set -e
set -o pipefail

# Runs once per night, after everything else: bundles the night's intermediate products into {JD}_*.tar.gz archives
# for cold storage (as H6C's do_CLEANUP.sh). Nothing is deleted here. What is bundled is up to the toml: each
# [DATA_PRODUCTS] entry with retention = "archive" gets a bundle of its own, {JD}_<NAME>.tar.gz, beside its files,
# and so do the rendered notebooks below, which aren't data products. The files each bundle was built from are
# deleted only once the night has been reviewed, by operations/prune.sh, which first checks them against the
# bundle's .contents.txt.

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Positional args (must match phase_II_analysis.toml [CLEANUP])
fn=${1}
toml_file=${2}

jd=$(get_int_jd $(basename ${fn}))
cd "$(dirname "${fn}")"
sb_dir=$(dirname $(get_filename ${toml_file} CORNER_TURN_MAP))  # where the single-baseline files are

# --------------------------------------------------------------------
# Helper: write ARCHIVE from the files listed on stdin, one per line, and list them in ARCHIVE.contents.txt.
# The list is tar's input (-T, so that tens of thousands of baselines don't overflow the command line),
# and gets its final name only once tar has succeeded, so its presence means the bundle is complete;
# prune.sh deletes exactly the files it lists, and only if they haven't changed since.
# --------------------------------------------------------------------
make_tar () {
    local archive=$1                # the .tar.gz to write

    rm -f "${archive}.contents.txt"
    sort > "${archive}.contents.txt.tmp"
    # a glob that matched nothing is listed literally, so this catches something that was never made
    if [[ ! -e "$(head -n 1 "${archive}.contents.txt.tmp")" ]]; then
        echo "ERROR: nothing to bundle into ${archive}: $(head -n 1 "${archive}.contents.txt.tmp") doesn't exist" >&2
        rm -f "${archive}.contents.txt.tmp"
        exit 1
    fi
    tar -czf "${archive}" -T "${archive}.contents.txt.tmp"
    mv "${archive}.contents.txt.tmp" "${archive}.contents.txt"
    echo "Wrote ${archive} ($(wc -l < "${archive}.contents.txt" | tr -d ' ') files, $(du -h "${archive}" | cut -f1))."
}

# --------------------------------------------------------------------
# The data products to archive, each in a bundle beside its files
# (get_products fails if any product the toml says this workflow writes has no retention)
# --------------------------------------------------------------------
archived=$(get_products ${toml_file} archive)
for product in ${archived}; do
    files=$(get_product_files ${toml_file} ${jd} ${product})
    if [[ -z "${files}" ]]; then
        echo "ERROR: no ${product} files for ${jd}" >&2
        exit 1
    fi
    folder=$(dirname "${files%%$'\n'*}")
    archive=${jd}_${product}.tar.gz
    [[ "${folder}" == . ]] || archive=${folder}/${archive}
    echo "${files}" | make_tar "${archive}"
done

# --------------------------------------------------------------------
# The rendered notebooks (not data products): every <file or baseline>.sum.<kind>_notebook.html in the night's
# folder and the single-baseline folder, as the do scripts that render them name them, in one bundle per kind
# --------------------------------------------------------------------
for folder in . ${sb_dir}; do
    kinds=$(find ${folder} -maxdepth 1 -name "zen.${jd}.*.sum.*_notebook.html" | sed 's/.*\.sum\.//' | sort -u)
    for kind in ${kinds}; do
        prefix=$([[ ${folder} == . ]] || echo "${folder}/")
        printf '%s\n' ${prefix}zen.${jd}.*.sum.${kind} | make_tar "${prefix}${jd}_${kind%_notebook.html}_notebooks.tar.gz"
    done
done

echo "All archives created at $(date)."
