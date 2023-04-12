import os
from pathlib import Path

import toml

from .async_utils import subprocess_run


async def build(stage_day: Path, day: int):
    print(f"Running build for {day}")
    thisdir = Path('.') / str(day)
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

async def run(day: int, direc: Path = '.'):
    print(f"Running makeflow for {day}")
    thisdir = direc / str(day)
    mf = thisdir / toml.with_suffix(".mf").name
    if not mf.exists():
        raise ValueError(f"{mf} not found in {thisdir}")
    await subprocess_run(
        f"makeflow -T slurm -J 1 -r 0 {mf.name}",
        cwd=mf.parent
    )


async def run_makeflow(direc, day):
    print(f"Running run_makeflow for {day}")
    day = str(day)
    await build(direc / day, day)
    await run(day, direc)
    for fl in (direc/ day / day).glob("*"):
        fl.unlink()
