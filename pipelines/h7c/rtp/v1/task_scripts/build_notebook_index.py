#! /usr/bin/env python3.7
# -*- coding: utf-8 -*-
# Copyright 2021 the HERA Project
# Licensed under the MIT License

import argparse
import os
import re
import glob
from astropy.time import Time

starting_dir = os.getcwd()

# Parse arguments and move to target_directory
a = argparse.ArgumentParser(
    description='Script for building an index.html that links to files in this folder.'
)
a.add_argument("target_dir", help="Path to folder to make an index.html for.")
args = a.parse_args()
os.chdir(args.target_dir)

files = sorted(os.listdir(args.target_dir))
title = os.path.realpath(args.target_dir).split('/')[-1]

def make_links(files):

    links = []
    for file in files:
        if os.path.basename(file) == 'index.html':
            continue
        JD_strs = re.findall(r"2\d{6}", file)

        date_str = ''
        if len(JD_strs) > 0:
            utc = Time(JD_strs[-1], format='jd').datetime
            date_str = f' ({utc.year}-{utc.month}-{utc.day})'
        links.append(f'    <li><a href="{file}">{file}{date_str}</a></li>')

links = make_links(files)
with open('index.html', 'w') as f:
    f.write(f'<html>\n<title>{title}</title>\n<header>\n<h1>{title}</h1>\n</header>\n<body>\n<ul>\n')
    f.write('<li><a href=".."><b>Back to all notebooks.</b></a></li>')
    f.write('\n'.join(links))
    f.write('\n</ul>\n</body>\n</html>')


os.chdir('..')

all_html_files = glob.glob(f"./*/*.html", recursive=True)
mod_times = [os.path.getmtime(f) for f in all_html_files]
file_time_pairs = list(zip(all_html_files, mod_times))
recent_html_files = sorted(file_time_pairs, key=lambda x: x[1], reverse=True)[0:20]

links = make_links(recent_html_files)
overall_index = \
f"""<html>
<title>H7C_Notebooks</title>
<header>
<h1>H7C_Notebooks</h1>
</header>
<body>
<ul>
    <li><a href=".."><b>Back to all seasons.</b></a></li>
    <li><a href="antenna_classification_summary">antenna_classification_summary</a></li>
    <li><a href="calibration_smoothing">calibration_smoothing</a></li>
    <li><a href="data_inspect_all_ants">data_inspect_all_ants</a></li>
    <li><a href="file_calibration">file_calibration</a></li>
    <li><a href="full_day_antenna_flagging">full_day_antenna_flagging</a></li>
    <li><a href="full_day_auto_checker">full_day_auto_checker</a></li>
    <li><a href="full_day_rfi">full_day_rfi</a></li>
    <li><a href="index.html">index.html</a></li>
</ul>
<h2>Most Recent Notebooks:</h2>
<ul>
    {'\n'.join(links)}
</ul>
</body>
</html>"""
with open('index.html', 'w') as f:
    f.write(overall_index)

# move back to starting location
os.chdir(starting_dir)
