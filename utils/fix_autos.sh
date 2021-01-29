#!/bin/bash
# manual script to repair missing autocorrelations.
# should be run in folder holding all the .sum files

for sd in ("sum" "diff")
do
  for fn in *.${sd}.uvh5
  do
      autos_file=${fn/.${sd}.uvh5/.${sd}.autos.uvh5}
      if ![ -e "${fn}" "]
      then
        echo extract_autos.py ${fn} ${autos_file} --clobber
        extract_autos.py ${fn} ${autos_file} --clobber
      fi
  done
done
