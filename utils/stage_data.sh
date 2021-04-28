#!/bin/bash
jds=($@)
for jd in jds
do
  echo librarian stage-files -w local . '{"name-matches": "zen.${jd}.%"}'
  librarian stage-files -w local . '{"name-matches": "zen.${jd}.%"}'
done
