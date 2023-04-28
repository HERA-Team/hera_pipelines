import asyncio
import sys
from pathlib import Path
from subprocess import call

import click
from hera_cal import utils
from pyuvdata import UVBeam, UVCal, UVData

from . import async_utils, librarian_utils, mf_utils

main = click.Group()


@main.command()
@click.argument("direc", type=click.Path(exists=True, dir_okay=True, file_okay=False))
def fix_autos(direc):
    """Extract autos from all sum/diff UVH5 files in DIREC."""
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
    """Convert beamfits INFILE to hera_pspec-compatible format and save to OUTFILE.

    Produces two files: OUTFILE.fits and OUTFILE_pstokes.fits.
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
    """Discard antennas flagged in YAMLFILE from cal or data files given by INFILES."""

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
    """Make a README.md file for a github REPO with links to all notebooks.

    repo
        Path to folder in github repo to make a links README.md for.
    """
    from .repo_management import make_notebook_readme
    make_notebook_readme(repo)


@main.command()
@click.option("--max-simultaneous-days", "-n", type=int, default=10, help='maximum number of days to run simultaneously (save disk space)')
@click.option("-f/-F", "--force/--no-force", help="rerun everything even if done before")
@click.option("--start", type=int, default=2459847, help="start day")
@click.option("--end", type=int, default=2460030, help="end day")
@click.option("--direc", type=click.Path(exists=True, dir_okay=True, file_okay=False), default=".", help="directory to run in. Must contain a .toml file")
@click.option("--skip-days-with-outs/'--no-skipping", default=False, help="skip days with output files already present. Note that just because output files exist, doesn't mean everything has been run correctly.")
@click.option("--keep-day-if-failed/--no-keep-day-if-failed", default=False, help="keep day directory if any makeflow for that day failed.")
@click.option('-i', '--include-day', type=int, multiple=True, help='run only these days')
def run_days_async(max_simultaneous_days, force, start, end, direc, skip_days_with_outs, keep_day_if_failed, include_day: list[int]):
    """Run all days in parallel."""

    async def run_day(day, stage_dir, root_stage):
        await librarian_utils.stage_day(stage_dir, root_stage, day)
        await mf_utils.run_makeflow(stage_dir.parent, day, keep_day_if_failed=keep_day_if_failed)

    async def run_day_loop(days, stage_dir, root_stage, max_simultaneous_days):
        all_coroutines = [run_day(day, stage_dir, root_stage) for day in days]
        await async_utils.gather_with_concurrency(max_simultaneous_days, *all_coroutines)

    direc = Path(direc)
    days = sorted(direc.glob("245*"))
    days = [day for day in days if start <= int(day.name) <= end]

    if include_day:
        days = [day for day in days if int(day.name) in include_day]

    if force:
        print("REMOVING ALL OUTPUT FILES AND RESTARTING")
        for day in days:
            outs = sorted(day.glob("*.out"))
            print(f"  Remove {len(outs)} completed jobs in {day.name}")
            for out in outs:
                out.unlink()
            mflow = list(day.glob("*.makeflowlog"))
            if mflow:
                mflow[0].unlink()

    for day in days:
        errors = sorted(day.glob("*.error"))
        for error in errors:
            error.unlink()

    days = range(start, end + 1)

    # Skip all the days that are already done
    if skip_days_with_outs:
        days = [day for day in days if not list((direc / str(day)).glob("*.out"))]

    stage_dir= direc / 'staging'
    if not stage_dir.exists():
        stage_dir.mkdir()

    root_stage = Path('/lustre/aoc/projects/hera/H6C')

    asyncio.run(run_day_loop(days, stage_dir, root_stage, max_simultaneous_days))
