#! /bin/bash
set -e

# This runs after all MAKE_MINI_DATASET jobs have finished. It checks that every output file exists and
# has the expected shape, makes any that are missing or incomplete, and warns about stray files in the
# output folder. Takes the same arguments as do_MAKE_MINI_DATASET.sh.

src_dir="$(dirname "$0")"
${src_dir}/do_MAKE_MINI_DATASET.sh "$@" --finalize
