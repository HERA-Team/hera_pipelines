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
        if (outdir / fl.name).exists() and not clobber:
            print(f"  File already exists. Skipping...")
            continue
        
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
        uvd.write_uvh5(
            outdir / fl.name, clobber=clobber, fix_autos=True
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
    print("  > Reading reference data")
    ref_uvdata = UVData.from_file(reffile, read_data=True)
    ref_uvdata.set_rectangularity()

    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"    Reading reference data took {dt:.2f} minutes.")

    # Figure out which simulation files to read in.
    t1 = time.time()
    print("  > Selecting simulation files...")
    dlst_ref = np.median(np.diff(data_lsts))
    first_sim_index = np.argwhere(sim_lsts <= data_lsts.min() - dlst_ref).flatten()[-1]
    last_sim_index = np.argwhere(sim_lsts >= data_lsts.max() + dlst_ref).flatten()[0]
    sim_files = sim_files[first_sim_index:last_sim_index+1]
    print(f"    Found {len(sim_files)} files between LST {data_lsts.min() - dlst_ref:.6f} and {data_lsts.max() + dlst_ref:.6f}.")
    print(f"    First file: {sim_files[0].name}")
    print(f"    Last file:  {sim_files[-1].name}")
    
    # Before loading in the files, figure out which antennas to select.
    ref_bls = ref_uvdata.get_antpairs()

    if reds is not None:
        sim_bls_to_read = []
        for ref_bl in ref_bls:
            
            _bls = reds.get_reds_in_bl_set(
                ref_bl,
                bl_set=sim_antpairs,
                include_conj=True,
                match_conj_to_set=False,
                include_conj_only_if_missing=True,
            )
            if len(_bls) == 1:
                sim_bls_to_read.append(list(_bls)[0])
            else:
                raise ValueError(
                    f"Zero or multiple redundant baselines found for antenna pair {_bls}"
                )
        
        
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"    Determining files and baselines took {dt:.2f} minutes.")

    # Now load in the files.
    print("  > Loading simulation data")
    t1 = time.time()
    # This handles conjugation correctly (matching ref)
    sim_uvdata = UVData.from_file(sim_files, bls=sim_bls_to_read)

    actual_aps = sim_uvdata.get_antpairs()
    for bl in sim_bls_to_read:
        if bl not in actual_aps:
            raise ValueError(f"Baseline {bl} not found in simulation data.")
        
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"    Loading simulation data took {dt:.2f} minutes.")

    # Now interpolate the simulation data to the reference data times.
    print("  > Interpolating simulation to observed times")
    t1 = time.time()

    # We have all the necessary baselines in the sim data, but not in the same order
    # as the reference data. We need to sort them.
    
    required_indices = [actual_aps.index(ap) for ap in sim_bls_to_read]

    simdata = sim_uvdata.data_array
    if sim_uvdata.time_axis_faster_than_bls:
        simdata.shape = (sim_uvdata.Ntimes, sim_uvdata.Nbls) + sim_uvdata.data_array.shape[-2:]
        sim_lsts = sim_uvdata.lst_array[:sim_uvdata.Ntimes]
        simdata = simdata[:, required_indices]
        axis=0
    else:
        simdata.shape = (sim_uvdata.Nbls, sim_uvdata.Ntimes) + sim_uvdata.data_array.shape[-2:]
        sim_lsts = sim_uvdata.lst_array[::sim_uvdata.Nbls]
        simdata = simdata[required_indices]
        axis=1

    sim_lsts[sim_lsts < sim_lsts[0]] += 2*np.pi
    if not np.all(np.diff(sim_lsts) > 0):
        raise ValueError("Simulation LSTs are not strictly increasing after wrapping.")
    if not sim_lsts[0] < data_lsts[0]:
        raise ValueError("Simulation LSTs are not within the range of the observed LSTs.")
    if not data_lsts[-1] < sim_lsts[-1]:
        raise ValueError("Observed LSTs are not within the range of the simulation LSTs.")
    
    ref_uvdata.data_array = (
        interp1d(sim_lsts, simdata.real, axis=axis, kind="cubic")(data_lsts)
        + 1j * interp1d(sim_lsts, simdata.imag, axis=axis, kind="cubic")(data_lsts)
    )
    ref_uvdata.data_array.reshape((ref_uvdata.Nblts, ref_uvdata.Nfreqs, ref_uvdata.Npols))
    
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"    Interpolation took {dt:.2f} minutes.")

    return ref_uvdata

if __name__ == "__main__":
    typer.run(run)