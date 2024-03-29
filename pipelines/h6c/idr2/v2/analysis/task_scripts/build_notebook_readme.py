#! /usr/bin/env python3.7
# -*- coding: utf-8 -*-
# Copyright 2021 the HERA Project
# Licensed under the MIT License

import argparse
import os
import glob
from astropy.time import Time

starting_dir = os.getcwd()

# Parse arguments and move to target_directory
a = argparse.ArgumentParser(
    description='Script for building README files for a folder in a github repo with html and ipynb files that link to appropriate preview sites.'
)
a.add_argument("target_dir", help="Path to folder in github repo to make a links README.md for.")
args = a.parse_args()
os.chdir(args.target_dir)

# parse github url to get user and repo
stream = os.popen('git config --get remote.origin.url')
github_url = stream.read().strip()
if github_url[0:8] == "https://": # of the form https://github.com/HERA-Team/H4C_Notebooks.git
    user, repo = github_url.split('.com/')[-1].strip('.git').split('/')
elif "@" in github_url: # of the form git@h4cnotebooks.github.com:HERA-Team/H4C_Notebooks
    user, repo = github_url.split('github.com:')[-1].split('/')
    repo = repo.strip('.git')
sub_folders = os.path.abspath(os.getcwd()).split(repo + '/')[-1] 

# parse current branch
stream = os.popen('git rev-parse --abbrev-ref HEAD')
branch = stream.read().strip()

# build repo
readme = ['# Links to view files:', '']
for file in  sorted(glob.glob('*')):
    try:  # try to append dates in a parethetical
        JD = os.path.splitext(file)[0].split('_')[-1]
        utc = Time(JD, format='jd').datetime
        date_str = f' ({utc.year}-{utc.month}-{utc.day})'
    except:
        date_str = ''

    if file.endswith('.html'):
        readme.append(f'* [{file}{date_str}](https://htmlpreview.github.io/?https://github.com/{user}/{repo}/blob/{branch}/{sub_folders}/{file})')
    elif file.endswith('.ipynb'):
        readme.append(f'* [{file}{date_str}](https://nbviewer.jupyter.org/github/{user}/{repo}/blob/{branch}/{sub_folders}/{file})')


with open('README.md', 'w') as f:
    f.write('\n'.join(readme))

# move back to starting location
os.chdir(starting_dir)
