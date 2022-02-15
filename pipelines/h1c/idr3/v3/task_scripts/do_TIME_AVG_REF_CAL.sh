#! /bin/bash
set -e

# This script performs CLEAN-based inpainting of smooth_calibrated autocorrelations.

# import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - dly_ranges in the format [lower delay limit]~[upper delay limit]x[number of times repeated]
# 2-9 - see auto_reflection_run.py -h
# 10+ filenames
dly_ranges="${1}"
window="${2}"
alpha="${3}"
Nphs="${4}"
fthin="${5}"
ref_sig_cut="${6}"
edgecut_low="${7}"
edgecut_hi="${8}"
zeropad="${9}"
data_files="${@:10}"

# build list of inpainted autos files
ip_auto_files=()
for data_file in ${data_files[@]}; do
    ip_auto_file=`basename "$data_file"`
    ip_auto_file=$(remove_pol $ip_auto_file)
    ip_auto_file=${ip_auto_file%.HH.uv}.sum.autos.inpainted.uvh5 
    ip_auto_files+=( $ip_auto_file )
done

# build output calfile
fn=`basename ${data_files[0]}`
jd_int=$(get_int_jd ${fn})
output_fname=${fn%${jd_int}.*}${jd_int}.time_avg_ref_cal.calfits

# turn delay range string into the proper format, expanding multiples
expanded_dly_ranges=()
for dly_range in ${dly_ranges}; do
    start_dly=${dly_range%~*}
    end_dly=${dly_range#*~}
    end_dly=${end_dly%x*}
    repeats=${dly_range#*x}
    for n in `seq ${repeats}`; do 
        expanded_dly_ranges+=( "${start_dly},${end_dly}" )
    done
done

# build and execute command
cmd="auto_reflection_run.py ${ip_auto_files[@]} \
                            --output_fname ${output_fname} \
                            --time_avg \
                            --dly_ranges ${expanded_dly_ranges[@]} \
                            --window ${window} \
                            --alpha ${alpha} \
                            --edgecut_low ${edgecut_low} \
                            --edgecut_hi ${edgecut_hi} \
                            --zeropad ${zeropad} \
                            --Nphs ${Nphs} \
                            --fthin ${fthin} \
                            --ref_sig_cut ${ref_sig_cut} \
                            --write_npz \
                            --overwrite"
echo $cmd
$cmd
