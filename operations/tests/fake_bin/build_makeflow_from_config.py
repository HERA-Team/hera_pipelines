#! /bin/bash
# Stands in for hera_opm's build_makeflow_from_config.py: "-c <toml> <sum files>" writes <toml name>.mf, naming
# the sum files (which the fake makeflow_nrao.sh reads), and a wrapper script per file for each of the toml's
# [WorkFlow] actions.
toml=$2; shift 2
mf=$(basename "${toml}" .toml).mf
printf '%s\n' "$@" > "${mf}"
actions=$(python -c "import toml, sys; print(' '.join(toml.load(sys.argv[1])['WorkFlow']['actions']))" "${toml}")
for f in "$@"; do
    for action in ${actions}; do
        echo "true" > "wrapper_$(basename "${f}").${action}.sh"
    done
done
echo "Wrote ${mf} for $# files"
