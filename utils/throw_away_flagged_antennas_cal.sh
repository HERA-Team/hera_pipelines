#!/bin/bash

pydir="${1}"
datadir="${2}"
yamlfile="${3}"

for sumfile in ${datadir}/zen.*.sum.omni.calfits
do
  echo python ${pydir}throw_away_flagged_antennas_cal.py ${sumfile} ${yamlfile}
  python ${pydir}throw_away_flagged_antennas_cal.py ${sumfile} ${yamlfile}
done


for sumfile in ${datadir}/zen.*.sum.abs.calfits
do
  echo python ${pydir}throw_away_flagged_antennas_cal.py ${sumfile} ${yamlfile}
  python ${pydir}throw_away_flagged_antennas_cal.py ${sumfile} ${yamlfile}
done


for sumfile in ${datadir}/zen.*.sum.smooth_abs.calfits
do
  echo python ${pydir}throw_away_flagged_antennas_cal.py ${sumfile} ${yamlfile}
  python ${pydir}throw_away_flagged_antennas_cal.py ${sumfile} ${yamlfile}
done

for sumfile in ${datadir}/zen.*.sum.omni_vis.uvh5
do
  echo python ${pydir}throw_away_flagged_antennas_cal.py ${sumfile} ${yamlfile}
  python ${pydir}throw_away_flagged_antennas_cal.py ${sumfile} ${yamlfile}
done
