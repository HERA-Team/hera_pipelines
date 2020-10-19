#! /bin/bash
set -e

#import common functions
src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# This script averages data in time.
# Parameters are set in the configuration file, here we define their positions,
# which must be consistent with the config.
# 1 - template file name (template for time chunk to reconstitute).
# 2 - data extension
# 2 - output label for identifying file.
# 3 - number of seconds to average in time.

fn="${1}"
data_ext="${2}"
label="${3}"
t_avg="${4}"

jd=$(get_jd $fn)
int_jd=${jd:0:7}

auto_in_even=zen.${jd}.even.${label}.foreground_filtered_auto_filled.uvh5
auto_in_odd=${auto_in_even/even/odd}
auto_out_even=zen.${jd}.even.${label}.foreground_filtered_auto_filled.tavg.uvh5
auto_out_odd=${auto_out_even/even/odd}

nofg_in_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_noforegrounds_res.${data_ext}
nofg_in_odd=${nofg_in_even/even/odd}
nofg_out_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_noforegrounds_res.tavg.${data_ext}
nofg_out_odd=${nofg_out_even/even/odd}

fgfilled_in_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_filled.${data_ext}
fgfilled_in_odd=${nofg_in_even/even/odd}
fgfilled_out_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_filled.tavg.${data_ext}
fgfilled_out_odd=${nofg_out_even/even/odd}

fgres_in_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_res.${data_ext}
fgres_in_odd=${nofg_in_even/even/odd}
fgres_out_even=zen.${jd}.even.${label}.xtalk_filtered_waterfall_withforegrounds_res.tavg.${data_ext}
fgres_out_odd=${nofg_out_even/even/odd}


auto_list_even=`echo zen.${int_jd}.*.even.${label}.foreground_filtered_auto_filled.uvh5`
auto_list_odd=`echo zen.${int_jd}.*.odd.${label}.foreground_filtered_auto_filled.uvh5`
# time-average autocorrs using waterfall averaging cornerturn.
# even
echo time_avg_data_and_write_baseline_list.py ${auto_in_even} ${auto_out_even} ${auto_list_even} ${t_avg} --rephase --clobber
time_avg_data_and_write_baseline_list.py ${auto_in_even} ${auto_out_even} ${t_avg} --rephase --clobber
# odd
echo time_avg_data_and_write_baseline_list.py ${auto_in_odd} ${auto_out_odd} ${auto_list_even} ${t_avg} --rephase --clobber
time_avg_data_and_write_baseline_list.py ${auto_in_odd} ${auto_out_odd} ${t_avg} --rephase --clobber

# time-average no-fg resids -- use for id weight estimator.
# even
echo time_average.py ${nofg_in_even} ${nofg_out_even} ${t_avg} --rephase --clobber --flag_output
time_average.py ${nofg_in_even} ${nofg_out_even} ${t_avg} --rephase --clobber --flag_output zen.${jd}.${label}.roto_flags.tavg.flags.h5
# odd
echo time_average.py ${nofg_in_odd} ${nofg_out_odd} ${t_avg} --rephase --clobber
time_average.py ${nofg_in_odd} ${nofg_out_odd} ${t_avg} --rephase --clobber

# time-average with-fg filled -- use for signal loss estimation.
# even
echo time_average.py ${fgfilled_in_even} ${fgfilled_out_even} ${t_avg} --rephase --clobber
time_average.py ${fgfilled_in_even} ${fgfilled_out_even} ${t_avg} --rephase --clobber
# odd
echo time_average.py ${fgfilled_in_odd} ${fgfilled_out_odd} ${t_avg} --rephase --clobber
time_average.py ${fgfilled_in_odd} ${fgfilled_out_odd} ${t_avg} --rephase --clobber


# time-average with-fg resids -- use for dayenu estimator.
