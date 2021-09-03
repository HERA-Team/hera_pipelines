import glob
from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive
import sys

gauth = GoogleAuth()
gauth.LocalWebserverAuth()
drive = GoogleDrive(gauth)

import glob

folder_id = sys.argv[1] # to get this, navigate to folder in gdrive website
                                                # and copy string after "/folder/" in url.

sleeptime = float(sys.argv[2]) # time to sleep between each upload (avoid hitting request limits)
filelist = sys.argv[3:] # list of files to process

uploaded = drive.ListFile({'q': f"'{folder_id}' in parents and trashed=false"}).GetList()
uploaded = [file['title'] for file in uploaded] # format so only their titles are in the list.



for fn in tqdm.tqdm(file_list):
    ftitle = fn.split('/')[-1]
    if ftitle not in uploaded:
        status = False
        # keep trying to upload, even if pipe gets broken.
        while not status:
            try:
                file = drive.CreateFile({'parents': [{'id': folder_id}]})
                file.SetContentFile(fn)
                file['title'] = ftitle
                file.Upload()
                status=True
                time.sleep(sleeptime)
            except:
                status=False
                time.sleep(sleeptime)
