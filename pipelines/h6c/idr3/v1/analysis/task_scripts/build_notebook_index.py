#! /usr/bin/env python3.7
# -*- coding: utf-8 -*-
# Copyright 2021 the HERA Project
# Licensed under the MIT License

import argparse
import os
import re
import glob
from astropy.time import Time

# Parse arguments
a = argparse.ArgumentParser(
    description='Script for building an index.html that links to files in this folder.'
)
a.add_argument("target_dir", help="Path to folder to make an index.html for.")
args = a.parse_args()

files = sorted(os.listdir(args.target_dir))
title = os.path.realpath(args.target_dir).split('/')[-1]

date_str_cache = {}
def make_links(files):
    links = []
    for file in files:
        if os.path.basename(file) == 'index.html':
            continue
        JD_strs = re.findall(r"2\d{6}", file)

        date_str = ''
        if len(JD_strs) > 0:
            if JD_strs[-1] in date_str_cache:
                date_str = date_str_cache[JD_strs[-1]]
            else:
                utc = Time(JD_strs[-1], format='jd').datetime
                date_str = f' ({utc.year}-{utc.month}-{utc.day})'
                date_str_cache[JD_strs[-1]] = date_str
        links.append(f'    <li><a href="{file}">{file.split("/")[-1]}{date_str}</a></li>')
    return links

links = make_links(files)
with open(os.path.join(args.target_dir, 'index.html'), 'w') as f:
    f.write(f'<html>\n<title>{title}</title>\n<header>\n<h1>{title}</h1>\n</header>\n<body>\n<ul>\n')
    f.write('<li><a href=".."><b>Back to all notebooks.</b></a></li>')
    f.write('\n'.join(links))
    f.write('\n</ul>\n</body>\n</html>')


starting_dir = os.getcwd()
os.chdir(os.path.join(args.target_dir, '..'))

all_html_files = [os.path.relpath(f) for f in glob.glob(os.path.join(args.target_dir, "../*/*.html"))]
mod_times = [os.path.getmtime(f) for f in all_html_files]
file_time_pairs = list(zip(all_html_files, mod_times))
recent_html_files = [pair[0] for pair in sorted(file_time_pairs, key=lambda x: x[1], reverse=True)][0:200]
links = make_links(recent_html_files)
recent_jds = sorted(list(set([int(jd) for link in links for jd in re.findall(r"2\d{6}", link)])), reverse=True)

overall_index = '<html>\n<title>H6C IDR3 Notebooks</title>\n<header>\n<h1>H6C IDR3 Notebooks</h1>\n</header>\n<body>\n<h3><ul>\n'
overall_index += '    <li><a href=".."><b>Back to H6C.</b></a></li>\n'
overall_index += '    <li><a href="file_calibration">file_calibration</a></li>\n'
overall_index += '    <li><a href="antenna_classification_summary">antenna_classification_summary</a></li>\n'
overall_index += '    <li><a href="full_day_antenna_flagging">full_day_antenna_flagging</a></li>\n'
overall_index += '    <li><a href="full_day_rfi">full_day_rfi</a></li>\n'
overall_index += '    <li><a href="calibration_smoothing">calibration_smoothing</a></li>\n'
overall_index += '    <li><a href="delay_filtered_average_zscore">delay_filtered_average_zscore</a></li>\n'
overall_index += '    <li><a href="full_day_rfi_round_2">full_day_rfi_round_2</a></li>\n'
overall_index += '    <li><a href="file_postprocessing">file_postprocessing</a></li>\n'
overall_index += '    <li><a href="single_baseline_2D_filtered_SNRs">single_baseline_2D_filtered_SNRs</a></li>\n'
overall_index += '    <li><a href="full_day_rfi_round_3">full_day_rfi_round_3</a></li>\n'
overall_index += '    <li><a href="single_baseline_2D_informed_inpaint">single_baseline_2D_informed_inpaint</a></li>\n'
overall_index += '    <li><a href="full_day_systematics_inspect">full_day_systematics_inspect</a></li>\n'
overall_index += '    <li><a href="lstbin">lstbin</a></li>\n'
overall_index += '</ul>\n</h3>\n<h2>Notebooks by JD:</h2>\n'
for jd in recent_jds[:]:
    overall_index += f'<h3>{jd}:</h3>\n<ul>\n' + '\n'.join([link for link in links if str(jd) in link]) + '\n</ul>\n'
overall_index += "</body>\n</html>"

with open('index.html', 'w') as f:
    f.write(overall_index)

# move back to starting location
os.chdir(starting_dir)
