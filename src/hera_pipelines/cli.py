import sys
from pathlib import Path
from subprocess import call

import click
from hera_cal import utils
from pyuvdata import UVBeam, UVCal, UVData

main = click.Group()


@main.command()
@click.argument("direc", type=click.Path(exists=True, dir_okay=True, file_okay=False))
def fix_autos(direc):
    """Fix autos in a UVFITS file."""
    direc = Path(direc)

    all_sums_and_diffs = list(direc.glob("zen.*.sum.uvh5"))

    for fl in all_sums_and_diffs:
        auto_fl = fl.with_suffix(".autos.uvh5")
        if not auto_fl.exists():
            call(["extract_autos.py", str(fl), str(auto_fl)])

@main.command()
@click.argument("infile", type=click.Path(exists=True, dir_okay=False, file_okay=True))
@click.argument("outfile", type=click.Path(exists=False, dir_okay=False, file_okay=True))
def fix_beam(infile, outfile):
    """Fix a beam file.

    Produces two files: output.fits and output_pstokes.fits.
    """
    output_file = f'{outfile}.fits'
    pstokes_output_file = f'{outfile}_pstokes.fits'

    uvbeam = UVBeam()
    uvbeam.read_beamfits(infile)
    uvbeam.x_orientation = 'north'
    uvbeam.history += f"produced with hp fix-beam {infile} {outfile}"
    uvbeam.write_beamfits(output_file, clobber=True)
    # convert to pstokes
    uvbeam.efield_to_pstokes(inplace=True)
    uvbeam.write_beamfits(pstokes_output_file, clobber=True)

@main.command()
@click.argument("yamlfile", type=click.Path(exists=True, dir_okay=False, file_okay=True))
@click.argument("infiles", type=click.Path(exists=True, dir_okay=False, file_okay=True), nargs=-1)
def discard_flagged_ants(yamlfile, infiles):
    """Discard flagged antennas from calibration or data files."""

    for infile in infiles:
        if infile.endswith(".calfits"):
            uv = UVCal()
            uv.read_calfits(infile)
            uv = utils.apply_yaml_flags(uv, yamlfile, ant_indices_only=True, flag_ants=True, flag_freqs=False, flag_times=False, throw_away_flagged_ants=True)
            uv.write_calfits(infile, clobber=True)
        elif infile.endswith(".uvh5"):
            uv = UVData()
            uv.read(infile)
            uv = utils.apply_yaml_flags(uv, yamlfile, ant_indices_only=True, flag_ants=True, flag_freqs=False, flag_times=False, throw_away_flagged_ants=True)
            uv.write_uvh5(infile, clobber=True)
        else:
            print(f"Unrecognized file type for {infile}")

@main.command()
@click.option("--data-folder", required=True, type=str, help="unique identifier for google drive folder containing observations. To find this, navigate to google drive folder and find string in url after '/folder/...'")
@click.option("-i", "--data-files", required=True, type=click.Path(exists=True, dir_okay=False, file_okay=True), multiple=True, help="List of datafiles to upload.'")
@click.option("--sleep-time", type=float, default=0., help="time interval to wait between uploading each file.")
@click.option("--retry-time", type=float, default=60., help="time interval to wait on a failure to connect before retrying. ")
@click.option("--clobber/--shy", default=False, help="Overwrite already uploaded files on gdrive. ")
def gdrive_upload(data_folder, data_files, sleep_time, retry_time, clobber):
    """Upload files to Google Drive."""
    from .gdrive import upload_gdrive
    upload_gdrive(
        data_folder=data_folder, data_files=data_files,
        sleep_time=sleep_time, retry_time=retry_time, clobber=clobber
    )

@main.command()
@click.argument("repo", type=click.Path(exists=True, dir_okay=True, file_okay=False))
def notebook_readme(repo):
    """Make a README.md file for a github repo with links to all notebooks.

    repo
        Path to folder in github repo to make a links README.md for.
    """
    from .repo_management import make_notebook_readme
    make_notebook_readme(repo)
