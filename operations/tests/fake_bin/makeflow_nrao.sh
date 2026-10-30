#! /bin/bash
# Stands in for hera_opm's makeflow_nrao.sh: "makeflow_nrao.sh <mf> <max jobs>" writes a makeflow log as ten jobs
# finish (FAKE_JOB_SECONDS apart), and then a job log and .out for each wrapper, as makeflow's jobs would. Nights
# listed in FAKE_FAIL_JDS fail the first time they are run, with one failed job, and succeed when rerun.
# A pipeline's tests can set FAKE_MAKEFLOW_PRODUCTS to a script that makes the products the night's real makeflow
# would; it runs in the night's folder, with the first sum file's name, and the makeflow fails if it does.
mf=$1
log=${mf}.makeflowlog
first_file=$(head -n 1 "${mf}")
night_dir=$(dirname "${first_file}")
jd=$(basename "${night_dir}")
stamp () { echo "$(date +%s)000000"; }

echo "# STARTED $(stamp)" >> "${log}"
failing=$([[ " ${FAKE_FAIL_JDS} " == *" ${jd} "* && ! -e failed_once ]] && echo 1 || echo 0)
for i in $(seq 1 10); do
    sleep ${FAKE_JOB_SECONDS:-0}
    if (( failing && i == 7 )); then
        echo "$(stamp) ${i} 3 ${i} $(( 10 - i )) 0 $(( i - 1 )) 1 0 10" >> "${log}"
        echo "Traceback: something went wrong" > "zen.${jd}.12345.sum.uvh5.SOME_JOB.log.error"
        touch failed_once
        echo "# FAILED $(stamp)" >> "${log}"
        echo "makeflow: 1 job failed" >&2
        exit 1
    fi
    echo "$(stamp) ${i} 2 ${i} $(( 10 - i )) 0 ${i} 0 0 10" >> "${log}"
done

if [[ -n "${FAKE_MAKEFLOW_PRODUCTS}" ]] && ! (cd "${night_dir}" && bash "${FAKE_MAKEFLOW_PRODUCTS}" "$(basename "${first_file}")"); then
    echo "# FAILED $(stamp)" >> "${log}"
    exit 1
fi

for wrapper in wrapper_*.sh; do
    job=${wrapper#wrapper_}
    echo "log" > "${job%.sh}.log"
    touch "${job%.sh}.out"
done
echo "# COMPLETED $(stamp)" >> "${log}"
