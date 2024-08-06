import asyncio
import sys
from pathlib import Path
from subprocess import call

import click
from hera_cal import utils
from jinja2 import Template
from pyuvdata import UVBeam, UVCal, UVData
from rich.console import Console

from . import async_utils, librarian_utils, mf_utils, seasons

main = click.Group()

cns = Console()
print = cns.print

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
@click.option("--end", type=int, default=2460050, help="end day")
@click.option("--direc", type=click.Path(exists=True, dir_okay=True, file_okay=False), default=".", help="directory to run in. Must contain a .toml file")
@click.option("--skip-days-with-outs/'--no-skipping", default=False, help="skip days with output files already present. Note that just because output files exist, doesn't mean everything has been run correctly.")
@click.option("--keep-day-if-failed/--no-keep-day-if-failed", default=False, help="keep day directory if any makeflow for that day failed.")
@click.option('-i', '--include-day', type=int, multiple=True, help='run only these days')
@click.option("-s", "--season", default='H6C', type=click.Choice(list(seasons.seasons.keys())), help="The season to use to provide default values for the other options.")
@click.option("--root-stage", type=click.Path(exists=True, dir_okay=True, file_okay=False), default=None, help="root stage directory to use. If not provided, will use the default for the season.")
def run_days_async(max_simultaneous_days, force, start, end, direc, skip_days_with_outs, keep_day_if_failed, include_day: list[int], season, root_stage):
    """Run all days in parallel."""
    if root_stage is None:
        root_stage = Path(seasons.seasons[season].root_stage)

    async def run_day(day, stage_dir, root_stage):
        await librarian_utils.stage_day(stage_dir, root_stage, day)
        await mf_utils.run_makeflow(stage_dir.parent, day, keep_day_if_failed=keep_day_if_failed)

    async def run_day_loop(days, stage_dir, root_stage, max_simultaneous_days):
        all_coroutines = [run_day(day, stage_dir, root_stage) for day in days]
        await async_utils.gather_with_concurrency(max_simultaneous_days, *all_coroutines)

    direc = Path(direc)
    days = sorted(direc.glob("24?????"))
    days = [day for day in days if start <= int(day.name) <= end]
    if include_day:
        days = [day for day in days if int(day.name) in include_day]

    cns.print(f"Requested days {', '.join(d.name for d in days)}")

    if force and skip_days_with_outs:
        cns.print("[bold red]You have set --force and --skip-days-with-outs, which are incompatible")
        sys.exit(1)

    if force:
        cns.print("Forcing rerun of all days... removing .out files")
        for day in days:
            outs = sorted(day.glob("*.out"))
            cns.print(f"  Removed {len(outs)} completed jobs in {day.name}")
            for out in outs:
                out.unlink()
            mflow = list(day.glob("*.makeflowlog"))
            if mflow:
                mflow[0].unlink()

    for day in days:
        errors = sorted(day.glob("*.error"))
        for error in errors:
            error.unlink()

    days = [day.name for day in days]

    # Skip all the days that are already done
    if skip_days_with_outs:
        _days = []
        for day in days:
            if list((direc / str(day)).glob("*.out")):
                cns.print(f"Skipping day {day} because it has output files already, and --skip-days-with-outs was set.")
            else:
                _days.append(day)
        days = _days

    stage_dir= direc / 'staging'
    if not stage_dir.exists():
        stage_dir.mkdir()


    cns.print(f"[bold blue]Starting aynchronous loop over {len(days)} days with {max_simultaneous_days} simultaneous days")
    asyncio.run(run_day_loop(days, stage_dir, root_stage, max_simultaneous_days))


@main.command()
@click.option("--season", type=click.Choice(list(seasons.seasons.keys())))
@click.option("--idr", type=int)
@click.option("--gen", type=int)
@click.option("--repodir", default='.', type=click.Path(exists=True, dir_okay=True, file_okay=False))
@click.option("-f/-F", "--force/--no-force", help="overwrite existing")
@click.option(
    "--cases", multiple=True,
    type=click.Tuple([
        click.Choice(['redavg', 'nonavg']), click.Choice(['abscal', 'smoothcal']), click.Choice(['dlyfilt', 'inpaint']),
        str, click.Choice(['lstcal', 'nolstcal'])
    ]),
    help="quintuplet of [redavg/nonavg, abscal/smoothcal, dlyfilt/inpaint, inpaintdelay (e.g. '500ns'), lstcal/nolstcal]"
)
@click.option("--setup-analysis/--only-repo", default=None, help="whether to also softlink output tomls to the analysis dir")
@click.option('--prefix', type=str, default='', help='a prefix to add to the casenames')
@click.option("--all-cases/--specify-cases", default=True,)
def lstbin_setup(season, idr, gen, repodir, cases, force, setup_analysis, prefix, all_cases):
    """Setup lstbin TOML files for a range of cases for a specific SEASON, IDR, and GENERATION.

    The TOML file created contains *both* the appropriate configuration for the
    LSTBin Configurator setup, as well as the standard hera_opm config, and also the
    configuration for the actual averaging using the notebook.

    Example for SEASON is "h6c" (which is also the first season this script works for).
    The IDR is specified as "IDR.GENERATION" (eg. IDR 2.1)

    This creates the
    """
    repodir = Path(repodir).absolute()
    template = repodir / f"pipelines/{season}/idr{idr}/v{gen}/lstbin/lstbin-template.toml"

    if not seasons.seasons[season]['analysis_dir'].exists():
        if setup_analysis:
            print(":warning-emoji: [red]You specified --setup-analysis but the analysis directory does not exist[/]")

        # Can't setup the analysis directory because we're not on lustre.
        setup_analysis = False
    elif setup_analysis is None:
        setup_analysis = True

    if not template.exists():
        print(f"Template {template} does not exist")
        sys.exit(1)

    if all_cases and len(cases)==0:
        cases = [
            ('redavg', 'smoothcal', 'inpaint', '500ns', 'lstcal'),  # Default case
            ('redavg', 'abscal', 'inpaint', '500ns', 'lstcal'), 
            ('redavg', 'smoothcal', 'dlyfilt', '500ns', 'lstcal'),
            ('redavg', 'smoothcal', 'inpaint', '1000ns', 'lstcal'),
            ('redavg', 'smoothcal', 'inpaint', '500ns', 'nolstcal'),
            ('nonavg', 'smoothcal', 'inpaint', '500ns', 'nolstcal'), # no LST cal possible
        ]

    for case in cases:
        redavg, callevel, mdltype, inpdelay, lstcal = case

        casename = f"{prefix}{redavg}-{callevel}-{mdltype}-{inpdelay}-{lstcal}"
        toml_file = repodir / f"pipelines/{season}/idr{idr}/v{gen}/lstbin/{casename}/lstbin.toml"
        if toml_file.exists() and not force:
            print(f":warning: File '{toml_file}' exists and --force was not set. [red]Skipping[/].")
            continue

        toml_file.parent.mkdir(exist_ok=True, parents=True)
        with open(template) as f:
            toml = Template(f.read())

        if mdltype == 'dlyfilt':
            EXTENSION = ".dly_filt"
        elif mdltype=='inpaint' and (idr <=2 and gen < 3):
            EXTENSION = ".inpaint"
        else:
            EXTENSION = ""

        kw = dict(
            REPODIR = repodir,
            SEASON = season,
            IDR = idr,
            GENERATION = gen,
            ANALYSISDIR = seasons.seasons[season]['analysis_dir'],
            CASENAME = casename,
            INPAINT_EXT="none" if mdltype == "dlyfilt" else ".where_inpainted.h5",
            DATA_EXT="" if redavg=='nonavg' else (
                f".abs_calibrated.red_avg{EXTENSION}" if callevel=='abscal' else f".smooth_calibrated.red_avg{EXTENSION}"
            ),
            INPAINT_FORMAT="{inpaint_mode}/" if mdltype == "inpaint" else "",
            CALEXT=".smooth.calfits" if callevel == "smoothcal" and redavg=='nonavg' else (
                ".abs.calfits" if callevel=='abscal' and redavg=='nonavg' else 'none'
            ),
            FLAGGED_AVERAGE = mdltype=='dlyfilt',
            REDAVG=redavg=='redavg',
            INPAINT_DELAY = inpdelay[:-2],
            DO_LSTCAL = lstcal=='lstcal',
        )
        rendered = toml.render(**kw)

        with open(toml_file, 'w') as f:
            f.write(rendered)

        print(f"[green]✓[/] Wrote case [blue]{casename}[/] to '{toml_file}'")

        if setup_analysis:
            anldir = seasons.seasons[season]['analysis_dir'] / f"IDR{idr}/makeflow-lstbin/v{gen}/{casename}"
            if not anldir.exists():
                anldir.mkdir(parents=True)
            anlfile = anldir / "lstbin.toml"
            if not anlfile.exists():
                anlfile.symlink_to(toml_file.absolute())
                print(f"[green]✓[/] Linked {anlfile} to {toml_file}")
