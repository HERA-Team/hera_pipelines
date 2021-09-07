#!/bin/bash

#! /bin/bash
set -e
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

fn="${1}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}
if [[ "$int_jd" == *"."* ]]; then
  jd=`echo ${fn} | grep -o "[0-9]\{1,2\}.[0-9]\{5\}"`
  jd="LST.${jd}"
fi

fn_resid=zen${jd}.resid_fit.uvh5
fn_model=zen${jd}.model_fit.uvh5
fn_gain=zen${jd}.gain_fit.calfits

echo calibrate_and_model_dpss.py --input_data_files ${fn} --model_outfilename ${fn_model} --resid_outfilename ${fn_resid} --gain_outfilename ${fn_gain} --verbose
calibrate_and_model_dpss.py --input_data_files ${fn} --model_outfilename ${fn_model} --resid_outfilename ${fn_resid} --gain_outfilename ${fn_gain} --verbose
