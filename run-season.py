import asyncio
import json
import os
import sys
import time
from argparse import ArgumentParser
from pathlib import Path

from hera_librarian import LibrarianClient


async def subprocess_run(cmd: str, **kw):
    proc = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        **kw
    )

    stdout, stderr = await proc.communicate()

    if stdout:
        print(f'{cmd!r}:\n[stdout]\n{stdout.decode()[:100]}')
    if proc.returncode:
        raise OSError(
            f"""{cmd!r} exited with {proc.returncode}.

[stderr] ---------------------------
{stderr.decode()}
------------------------------------
""")

def search(day: int):
    return f'{{"start-time-jd-greater-than": {day}, "start-time-jd-less-than": {int(day)+1}, "name-matches": "%.autos.uvh5"}}'

async def stage_autos_for_a_day(dest: Path, day: int, clobber: bool = False):
    """
    Tell the Librarian to stage files onto the local scratch disk.
    """
    # Let's do it
    client = LibrarianClient('local')

    # Get the username. We could make this a command-line option but I think it's
    # better to keep this a semi-secret. Note that the server does absolutely no
    # verification of the values that are passed in.

    import getpass

    user = getpass.getuser()

    # Resolve the destination in case the user provides, say, `.`, where the
    # server is not going to know what that means. This will need elaboration if
    # we add options for the server to come up with a destination automatically or
    # other things like that.
    our_dest = dest.resolve()

    marker_path = dest / "STAGING-IN-PROGRESS"
    t0 = time.time()

    if not marker_path.exists():
        _search = search(day)
        result = client.launch_local_disk_stage_operation(user, _search, str(our_dest))

        print(
            "Launched operation to stage {:d} instances ({:d} bytes) to {}".format(
                result["n_instances"], result["n_bytes"], dest
            )
        )
    else:
        print(f"Operation to stage day {day} already underway, waiting...")


    t0 = time.time()

    while marker_path.exists():
        await asyncio.sleep(3)

    if (dest /"STAGING-SUCCEEDED").exists():
        return

    try:
        with open(dest / "STAGING-ERRORS") as fl:
            msg = f"Staging completed , but with error!\n\n{fl.read()}"
        raise Exception(msg)
    except OSError as e:
        raise OSError(
            'staging finished but neiher "success" nor "error" indicator was '
            f"created (no file {dest}/STAGING-ERRORS)"
        ) from e


def search_day_autos(day):
    # Let's do it
    print(f"Searching for all autos on librarian for day {day}")
    client = LibrarianClient('local')
    result = client.search_files(search(day))['results']

    # It's a list of dicts.
    return result

async def stage_day(stage_dir, root_stage, day):
    day = str(day)
    day_stage = stage_dir / day
    if not day_stage.exists():
        day_stage.mkdir()

    # Cache the result of the search, because it takes a little time.
    result_fl = (day_stage / "auto-search-result.json")
    if result_fl.exists():
        with open(result_fl) as fl:
            fls_in_librarian = json.load(fl)
    else:
        fls_in_librarian = search_day_autos(day)
        with open(result_fl, 'w') as fl:
            json.dump(fls_in_librarian, fl)

    fls_on_lustre = list((root_stage / day).glob("*.autos.uvh5"))

    # I'm not sure if the librarian overwrites files. Let's do
    # a softlink to any files on lustre anyway, in case the librarian
    # acknowledges them and skips over existing files.
    stage_day_day = day_stage / day
    if not stage_day_day.exists():
        stage_day_day.mkdir()

    for fl in fls_on_lustre:
        fl_on_stage = stage_day_day / fl.name
        if not fl_on_stage.exists():
            fl_on_stage.symlink_to(fl)

    fls_staged = list(stage_day_day.glob("*.autos.uvh5"))
    if len(fls_staged) != len(fls_in_librarian):
        print(f"Staging all autos for day {day}")
        await stage_autos_for_a_day(dest=day_stage, day=day)

async def build(stage_day: Path, day: int):
    print(f"Running build for {day}")
    thisdir = here / str(day)
    if not thisdir.exists():
        thisdir.mkdir()

    # remove all previous wrapper files
    for fl in thisdir.glob("wrapper*.sh"):
        fl.unlink()

    script = thisdir / 'build.sh'
    with open(script, 'w') as fl:
        fl.write(f"""#!/bin/bash
build_makeflow_from_config.py -c {toml} -d {thisdir.absolute()} {stage_day}/{day}/*.sum.autos.uvh5
"""
        )

    os.system(f"chmod +x {script}")
    print(f"Executing build-script for {day}")
    await subprocess_run(f"bash {script}")

async def run(day: int):
    print(f"Running makeflow for {day}")
    thisdir = here / str(day)
    mf = thisdir / toml.with_suffix(".mf").name
    if not mf.exists():
        raise ValueError(f"{mf} not found in {thisdir}")
    await subprocess_run(
        f"makeflow -T slurm -J 1 -r 0 {mf.name}",
        cwd=mf.parent
    )


async def run_makeflow(stage_day, day):
    print(f"Running run_makeflow for {day}")
    await build(stage_day, day)
    await run(day)
    for fl in (stage_dir/ str(day) / str(day)).glob("*"):
        fl.unlink()

async def gather_with_concurrency(n, *coros):
    """Run a number of coroutines, but only ever n at a time"""
    semaphore = asyncio.Semaphore(n)

    async def sem_coro(coro):
        async with semaphore:
            return await coro
    return await asyncio.gather(*(sem_coro(c) for c in coros))


async def run_day(day, stage_dir, root_stage):
    await stage_day(stage_dir, root_stage, day)
    await run_makeflow(stage_dir/str(day), day)


async def run_day_loop(days, stage_dir, root_stage, max_simultaneous_days):
    all_coroutines = [run_day(day, stage_dir, root_stage) for day in days]
    await gather_with_concurrency(max_simultaneous_days, *all_coroutines)


if __name__ == "__main__":


    parser = ArgumentParser()

    parser.add_argument("-n", "--max-simultaneous-days", type=int, default=10)
    parser.add_argument("-f", "--force", action='store_true', help='rerun everything even if done before')
    parser.add_argument("--start", type=int, default=2459847)
    parser.add_argument("--end", type=int, default=2460030)

    args = parser.parse_args()

    here = Path(__file__).parent

    toml = list(here.glob("*.toml"))[0]


    days = sorted(here.glob("245*"))

    if args.force:
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


    days = range(args.start, args.end + 1)

    stage_dir= here / 'staging'
    if not stage_dir.exists():
        stage_dir.mkdir()

    root_stage = Path('/lustre/aoc/projects/hera/H6C')

    asyncio.run(run_day_loop(days, stage_dir, root_stage, args.max_simultaneous_days))
