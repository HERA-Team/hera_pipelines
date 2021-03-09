#!/bin/bash

pydir="${1}"
datadir="${2}"
yamlfile="${3}"

for sumfile in ${datadir}/zen.*.sum.uvh5
do
  echo python ${pydir}throw_away_flagged_antennas.py ${sumfile} ${yamlfile}
  python ${pydir}throw_away_flagged_antennas.py ${sumfile} ${yamlfile}
done

for difffile in ${datadir}/zen.*.diff.uvh5
do
  echo python ${pydir}throw_away_flagged_antennas.py ${difffile} ${yamlfile}
  python ${pydir}throw_away_flagged_antennas.py ${difffile} ${yamlfile}
done
