#! /usr/bin/env python3.7
# -*- coding: utf-8 -*-
# Copyright 2021 the HERA Project
# Licensed under the MIT License

import argparse
import os
import re
import sys
import glob
from astropy.time import Time

TITLE = 'Phase II IDR 1 Notebooks'
SRC_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_TOML = os.path.join(SRC_DIR, '..', 'phase_II_analysis.toml')

sys.path.insert(0, SRC_DIR)  # this script is invoked by absolute path, from any cwd
import notebook_flowchart

# Parse arguments
a = argparse.ArgumentParser(
    description='Script for building an index.html that links to files in this folder.'
)
a.add_argument("target_dir", help="Path to folder to make an index.html for.")
a.add_argument("--toml", default=DEFAULT_TOML,
               help="Pipeline toml describing the workflow drawn on the top-level index.")
args = a.parse_args()
target_dir = os.path.abspath(args.target_dir)

files = sorted(os.listdir(target_dir))
title = os.path.realpath(target_dir).split('/')[-1]

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
with open(os.path.join(target_dir, 'index.html'), 'w') as f:
    f.write(f'<html>\n<title>{title}</title>\n<header>\n<h1>{title}</h1>\n</header>\n<body>\n<ul>\n')
    f.write('<li><a href=".."><b>Back to all notebooks.</b></a></li>')
    f.write('\n'.join(links))
    f.write('\n</ul>\n</body>\n</html>')


starting_dir = os.getcwd()
nb_output_repo = os.path.join(target_dir, '..')
os.chdir(nb_output_repo)

all_html_files = [os.path.relpath(f) for f in glob.glob(os.path.join(target_dir, "../*/*.html")) if os.path.exists(f)]
mod_times = [os.path.getmtime(f) for f in all_html_files]
file_time_pairs = list(zip(all_html_files, mod_times))
recent_html_files = [pair[0] for pair in sorted(file_time_pairs, key=lambda x: x[1], reverse=True)]
links = make_links(recent_html_files)
recent_jds = sorted(list(set([int(jd) for link in links for jd in re.findall(r"2\d{6}", link)])), reverse=True)

# The flowchart, the per-notebook list, and the folder-drift check are all derived from the
# workflow declared in the toml plus the do_ scripts, so they cannot fall out of step with
# the pipeline the way a hardcoded list of folders does.
flowchart, nodes = notebook_flowchart.render(args.toml, SRC_DIR, nb_output_repo)

overall_index = f'<html>\n<title>{TITLE}</title>\n<header>\n<h1>{TITLE}</h1>\n</header>\n<body>\n'
overall_index += '<p>Click a notebook to see its per-night renderings; hover for details.</p>\n'
overall_index += flowchart + '\n'

overall_index += '<h2>Notebooks by Type:</h2>\n<h3><ul>\n'
for node in nodes:
    if not node['is_notebook']:
        continue
    if node['exists']:
        overall_index += f'    <li><a href="{node["folder"]}">{node["folder"]}</a></li>\n'
    else:
        overall_index += f'    <li>{node["folder"]} <i>(not yet run)</i></li>\n'
overall_index += '</ul>\n</h3>\n'

# Any folder of notebooks that no action claims -- e.g. a do_ script whose nb_dest_dir was
# renamed, or notebooks copied in by hand -- would otherwise vanish from the page silently.
claimed = {node['folder'] for node in nodes if node['folder']}
unmapped = sorted({os.path.dirname(f) for f in all_html_files} - claimed - {''})
if unmapped:
    overall_index += '<h2>Unmapped Folders:</h2>\n'
    overall_index += '<p>These hold notebooks but match no action in the workflow.</p>\n<h3><ul>\n'
    for folder in unmapped:
        overall_index += f'    <li><a href="{folder}">{folder}</a></li>\n'
    overall_index += '</ul>\n</h3>\n'

overall_index += '<h2>Notebooks by JD:</h2>\n'
for jd in recent_jds[:]:
    overall_index += f'<h3>{jd}:</h3>\n<ul>\n' + '\n'.join([link for link in links if str(jd) in link]) + '\n</ul>\n'
overall_index += "</body>\n</html>"

with open('index.html', 'w') as f:
    f.write(overall_index)

# move back to starting location
os.chdir(starting_dir)
