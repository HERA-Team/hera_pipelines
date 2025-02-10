import re
import time
import numpy as np
from pathlib import Path
import typer
from typing import Annotated

from rich import console

from pyuvdata import UVData, FastUVH5Meta
from hera_cal.red_groups import RedundantGroups
from scipy.interpolate import interp1d

cns = console.Console()
print = cns.print

def run(
    reffile: Annotated[
        Path,
        typer.Option(
            exists=True,
            file_okay=True,
            dir_okay=False,
            writable=False,
            readable=True,
        ),
    ],
    sim_dir: Annotated[
        Path,
        typer.Option(
            exists=True,
            file_okay=False,
            dir_okay=True,
            writable=False,
            readable=True,
        )
    ] = Path("."),
    ref_is_redavg: bool = False,
    outdir: Annotated[
        Path,
        typer.Option(
            exists=True,
            file_okay=False,
            dir_okay=True,
            writable=True,
        )
    ] = Path('.'),
    clobber: bool = False,
):
    """Mock LST-binned data from perfectly calibrated simulations.

    This function takes an input UVData file, a sky component, and various
    configuration options to generate mock LST-binned data from perfectly
    calibrated simulations. It interpolates the simulation data to the
    observed LST-bins, handles antenna selection and flagging, and writes the
    resulting data to a new UVH5 file.
    """
    print("Beginning mock LSTBIN data routine...")
    init_time = time.time()

    # Get the perfectly-calibrated simulation files.
    t1 = time.time()
    print("Determining filing parameters...")

    # Obtain the LSTs for the reference files.
    ref_meta = FastUVH5Meta(reffile)
    lsts = ref_meta.lsts
    lsts[lsts < lsts[0]] += 2 * np.pi
    
    if ref_is_redavg:
        reds = RedundantGroups.from_antpos(
            antpos=dict(zip(ref_meta.telescope.antenna_numbers, ref_meta.antpos_enu))
        )
    else:
        reds = None
            
    lst_re = re.compile(r"\d+\.\d+")
    def sort(fn):
        return float(lst_re.findall(str(fn))[0])
    sim_files = sorted(sim_dir.glob("*.uvh5"), key=sort)
    start_lsts = np.array(
        [float(lst_re.findall(str(fn))[0]) for fn in sim_files]
    )  # We'll need these later.

    # Ensure that the LSTs are within pi of the reference LST.
    start_lsts[start_lsts<lsts[0] - np.pi] += 2 * np.pi
    start_lsts[start_lsts>lsts[0] + np.pi] -= 2 * np.pi
    
    sort = np.argsort(start_lsts)
    start_lsts = start_lsts[sort]
    sim_files = list(np.array(sim_files)[sort])

    # Figure out where to write the output.
    stem = re.findall(r"zen\.LST\.\d+\.\d+\.", reffile.name)[0]
    
    # Since there can be multiple basline-chunks for the same LST, we need to
    # find all of them (we're given only one of them).
    all_reffiles = reffile.parent.glob(f"{stem}*.uvh5")
    t2 = time.time()
    dt = (t2 - t1) / 60
    ref_meta.close()
    print(f"Setup took {dt:.2f} minutes.")

    # Get simulation reference data
    meta = FastUVH5Meta(sim_files[0])
    antpairs = meta.antpairs

    for fl in all_reffiles:
        print(f"Processing file: [blue]{fl.name}")
        uvd = interpolate_single_outfile(
            sim_lsts=start_lsts,
            data_lsts=lsts,
            reffile=fl,
            sim_files=sim_files,
            sim_antpairs=antpairs,
            reds=reds,
        )
        
        t1 = time.time()
        print("  Writing data to disk...", end="")
        uvd.write(
            outdir / fl.name, save_format="uvh5", clobber=clobber, fix_autos=True
        )
        t2 = time.time()
        dt = (t2 - t1) / 60
        print(f" took {dt:.2f} minutes.")

    end_time = time.time()
    runtime = (end_time - init_time) / 60
    print()
    print(f"[bold]Entire process took {runtime:.2f} minutes.")

        
def interpolate_single_outfile(
    sim_lsts: np.ndarray,
    data_lsts: np.ndarray, 
    reffile: Path, 
    sim_files: list[Path], 
    sim_antpairs: list[tuple[int, int]],
    reds: RedundantGroups | None = None,
) -> UVData:    
    # Start the interpolation routine.
    t1 = time.time()
    print("  Reading reference data...", end="")
    ref_uvdata = UVData.from_file(reffile, read_data=False)
    ref_uvdata.set_rectangularity()

    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f" took {dt:.2f} minutes.")

    # Figure out which simulation files to read in.
    t1 = time.time()
    print("  Selecting simulation files...", end="")
    dlst_ref = np.median(np.diff(data_lsts))
    first_sim_index = np.argwhere(sim_lsts <= data_lsts.min() - dlst_ref).flatten()[-1]
    last_sim_index = np.argwhere(sim_lsts >= data_lsts.max() + dlst_ref).flatten()[-1]

    sim_files = sim_files[first_sim_index:last_sim_index+1]

    # Before loading in the files, figure out which antennas to select.
    if ref_uvdata.time_axis_faster_than_bls:
        bls = list(zip(
            ref_uvdata.ant_1_array[::ref_uvdata.Ntimes], 
            ref_uvdata.ant_2_array[::ref_uvdata.Ntimes]
        ))
    else:
        bls = list(zip(
            ref_uvdata.ant_1_array[:ref_uvdata.Nbls], 
            ref_uvdata.ant_2_array[:ref_uvdata.Nbls]
        ))


    if reds is not None:
        bls = [
            reds.get_reds_in_bl_set(
                antpair,
                bl_set=bls,
                include_conj=True,
                match_conj_to_set=True,
                include_conj_only_if_missing=True,
            )
            for antpair in sim_antpairs
        ]
        
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f" took {dt:.2f} minutes.")

    # Now load in the files.
    print("  Loading simulation data...", end="")
    t1 = time.time()
    sim_uvdata = UVData.from_file(sim_files, bls=bls)
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f" took {dt:.2f} minutes.")

    # Now interpolate the simulation data to the reference data times.
    print("  Interpolating simulation to observed times...")
    t1 = time.time()

    if not np.all(sim_uvdata.get_antpairs() == ref_uvdata.get_antpairs()):
        raise ValueError("Antenna pairs do not match between reference and simulation.")
    
    simdata = sim_uvdata.data_array
    if sim_uvdata.time_axis_faster_than_bls:
        simdata.shape = (sim_uvdata.Ntimes, sim_uvdata.Nbls) + sim_uvdata.data_array.shape[-2:]
        axis=0
    else:
        simdata.shape = (sim_uvdata.Nbls, sim_uvdata.Ntimes) + sim_uvdata.data_array.shape[-2:]
        axis=1
        
    ref_uvdata.data_array = interp1d(sim_lsts, simdata, axis=axis, kind="cubic")(data_lsts)
    
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f" took {dt:.2f} minutes.")

    return ref_uvdata

if __name__ == "__main__":
    typer.run(run)