#!/usr/bin/env python

# script that uploads a list of files to a google drive folder.

import argparse
import os
from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive
import tqdm
import time
import sys



def upload_gdrive(data_folder, data_files, sleep_time=0.0, retry_time=60., clobber=False, retry=False):
    """
    Upload data_files to data_folder.
    """
    gauth = GoogleAuth()
    gauth.LocalWebserverAuth()
    drive = GoogleDrive(gauth)



    uploaded = drive.ListFile({'q': f"'{data_folder}' in parents and trashed=false"}).GetList()
    uploaded = [file['title'] for file in uploaded] # format so only their titles are in the list.



    for fn in tqdm.tqdm(data_files):
        ftitle = fn.split('/')[-1]
        if ftitle not in uploaded or clobber:
            status = False
            # keep trying to upload, even if pipe gets broken.
            while not status:
                try:
                    file = drive.CreateFile({'parents': [{'id': data_folder}]})
                    file.SetContentFile(fn)
                    file['title'] = ftitle
                    file.Upload()
                    status=True
                    time.sleep(sleep_time)
                except:
                    err = sys.exc_info()[0]
                    print(err)
                    status = not retry
                    if retry:
                        time.sleep(sleep_time)


ap = argparse.ArgumentParser(description='google drive data uploader')
ap.add_argument('--data_folder', type=str, required=True, help="unique identifier for google drive folder containing observations. To find this, navigate to google drive folder and find string in url after '/folder/...'")
ap.add_argument('--data_files', type=str, required=True, nargs="+", help="List of datafiles to upload.'")
ap.add_argument("--sleep_time", type=float, default=0., help="time interval to wait between uploading each file.")
ap.add_argument("--retry_time", type=float, default=60., help="time interval to wait on a failure to connect before retrying. ")
ap.add_argument("--clobber", default=False, action="store_true", help="Overwrite already uploaded files on gdrive. ")

#ap.add_argument('--mode', type=str, default='both', help="specify whether to download 'data', 'cal' or 'both'")

args = ap.parse_args()

upload_gdrive(data_folder=args.data_folder, data_files=args.data_files,
              sleep_time=args.sleep_time, retry_time=args.retry_time, clobber=args.clobber)
