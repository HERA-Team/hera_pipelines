#!/bin/bash
set -e

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consisten wtih the config.
# 1 - upload_to_librarian: boolean trigger
upload_to_librarian="${1}"

if [ "${upload_to_librarian}" == "True" ]; then
    # make new sessions in the librarian
    librarian assign-sessions local-rtp
fi
