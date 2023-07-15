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

links = []
for file in files:
    JD_strs = re.findall(r"2\d{6}", file)

    date_str = ''
    if len(JD_strs) > 0:
        utc = Time(JD_strs[-1], format='jd').datetime
        date_str = f' ({utc.year}-{utc.month}-{utc.day})'
    links.append(f'    <li><a href="{file}">{file}{date_str}</a></li>')

with open('index.html', 'w') as f:
    f.write(f'<html>\n<title>{title}</title>\n<header>\n<h1>{title}</h1>\n</header>\n<body>\n<ul>\n')
    f.write('<li><a href=".."><b>Back to all notebooks.</b></a></li>')
    f.write('\n'.join(links))
    f.write('\n</ul>\n</body>\n</html>')

# move back to starting location
os.chdir(starting_dir)
