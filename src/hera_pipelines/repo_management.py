import argparse
import glob
import os


def make_notebook_readme_links(target_dir,):
    starting_dir = os.getcwd()
    os.chdir(target_dir)

    # parse github url to get user and repo
    stream = os.popen('git config --get remote.origin.url')
    github_url = stream.read().strip()
    if github_url[:8] == "https://": # of the form https://github.com/HERA-Team/H4C_Notebooks.git
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
        if file.endswith('.html'):
            readme.append(f'* [{file}](https://htmlpreview.github.io/?https://github.com/{user}/{repo}/blob/{branch}/{sub_folders}/{file})')
        elif file.endswith('.ipynb'):
            readme.append(f'* [{file}](https://nbviewer.jupyter.org/github/{user}/{repo}/blob/{branch}/{sub_folders}/{file})')


    with open('README.md', 'w') as f:
        f.write('\n'.join(readme))

    # move back to starting location
    os.chdir(starting_dir)
