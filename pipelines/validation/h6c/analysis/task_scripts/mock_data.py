import argparse
import re
import time
import yaml
import numpy as np
from pathlib import Path

import hera_sim
from hera_sim import Simulator
from pyuvdata import UVData

parser = argparse.ArgumentParser()
parser.add_argument("infile", type=str, help="Data file to be referenced for sims")
parser.add_argument("sky_cmp", type=str, help="Sky component (e.g. diffuse).")
parser.add_argument(
    "--config", type=str, default="", help="Path to configuration file."
)
parser.add_argument(
    "--sim_dir", type=str, default=".", help="Path to directory containing simulation files."
)
parser.add_argument(
    "-o", "--outdir", type=str, default="", help="Absolute path to save directory."
)
# NOTE: we'll need to update this for H4C
parser.add_argument(
    "--lst_wrap", type=float, default=4.711094445, help="Where to wrap in LST."
)
parser.add_argument(
    "--clobber", default=False, action="store_true", help="Overwrite existing files."
)
parser.add_argument(
    "--inflate", default=False, action="store_true", help="Inflate data by redundancy."
)
parser.add_argument(
    "--input_is_compressed",
    default=False,
    action="store_true",
    help="Whether the input files are compressed by redundancy.",
)
parser.add_argument(
    "--flag_file",
    default="",
    help="Path to file containing apriori flags for this day.",
)
parser.add_argument(
    "--include_outriggers",
    default=False,
    action="store_true",
    help="Whether to include the outriggers in simulation.",
)

if __name__ == "__main__":
    # Setup
    print("Beginning mock data routine...")
    init_time = time.time()
    args = parser.parse_args()

    # Get the perfectly-calibrated simulation files.
    t1 = time.time()
    print("Determining filing parameters...")
    base_path = Path(args.sim_dir)
    sim_dir = base_path / args.sky_cmp
    lst_re = re.compile("\d+\.\d+")
    def sort(fn):
        return float(lst_re.findall(str(fn))[0])
    sim_files = sorted(sim_dir.glob("*.uvh5"), key=sort)
    start_lsts = np.array(
        [float(lst_re.findall(str(fn))[0]) for fn in sim_files]
    )  # We'll need these later.
    start_lsts[start_lsts<args.lst_wrap] += 2 * np.pi
    sort = np.argsort(start_lsts)
    start_lsts = start_lsts[sort]
    sim_files = list(np.array(sim_files)[sort])

    # Find the appropriate configuration file if not provided.
    jd = re.findall("\d{7}", args.infile)[0]
    if args.config:
        config_path = Path(args.config)
    else:
        config_path = base_path / f"config/{jd}.yaml"
    with open(config_path, "r") as cfg:
        config = yaml.load(cfg.read(), Loader=yaml.FullLoader)

    # Figure out where to write the uncalibrated file.
    infile = Path(args.infile)
    if args.outdir:
        outdir = Path(args.outdir)
    else:
        outdir = infile.parent
    stem = re.findall("zen.\d+\.\d+.sum", infile.name)[0]
    outfile = outdir / f"{stem}.uvh5"
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Setup took {dt:.2f} minutes.")

    # Start the interpolation routine.
    t1 = time.time()
    ref_uvdata = UVData()
    ref_uvdata.read(infile, read_data=False)
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Reading reference metadata took {dt:.2f} minutes.")

    # Figure out which files to read in.
    t1 = time.time()
    ref_times, sort_inds = np.unique(ref_uvdata.time_array, return_index=True)
    ref_lsts = ref_uvdata.lst_array[sort_inds]
    ref_lsts[ref_lsts<args.lst_wrap] += 2 * np.pi

    # Note that data LSTs will always be entirely to one side of the wrap.
    dref_lsts = np.median(np.diff(ref_lsts))
    first_ind = np.argwhere(start_lsts <= np.round(ref_lsts.min(), 7)).flatten()[-1]
    last_ind = np.argwhere(
        start_lsts <= np.round(ref_lsts.max() + dref_lsts, 7)
    ).flatten()[-1]

    # Before loading in the files, figure out which antennas to select.
    # The code for retrieving the flags assumes the H6C format for apriori flags.
    if args.flag_file:
        with open(args.flag_file, "r") as flag_info:
            bad_ants = np.array(
                yaml.load(flag_info.read(), Loader=yaml.SafeLoader)["ex_ants"]
            )[:,0].astype(int)
    else:
        bad_ants = np.array([], dtype=int)
    bad_ants = set(bad_ants)

    # The basic idea: we want to use all of the antennas that collected data
    # to try to make the mutual coupling as representative of the real thing
    # as possible. After systematics simulation, we want to downselect to
    # antennas that weren't completely flagged. Since the simulations have
    # more antennas than the data, we will need to downselect on antennas
    # twice: once before systematics simulation, and once after.
    sim_uvdata = UVData()
    sim_uvdata.read(sim_files[0], read_data=False)
    sim_ants = sorted(
        set(sim_uvdata.ant_1_array).union(sim_uvdata.ant_2_array)
    )
    data_ants = sorted(
        set(ref_uvdata.ant_1_array).union(ref_uvdata.ant_2_array)
    )
    if not args.include_outriggers:
        data_ants = [ant for ant in data_ants if ant < 320]
        sim_ants = [ant for ant in sim_ants if ant < 320]

    # Figure out which antennas to use for systematics simulation.
    ants_to_load = np.array(
        [ant for ant in sim_ants if ant in data_ants]
    )

    # Figure out which antennas to keep *after* systematics simulation.
    # NOTE: Here I'm assuming that the simulation antennas are a superset
    # of the data antennas. This should work for H6C and beyond, but it will
    # not necessarily be backwards-compatible with old validation simulations.
    # I'm sure there's a general solution that can handle all the corner cases
    # of pairs of array layouts (data:sim), but I don't want to figure out
    # the general solution right now.
    ants_to_keep = np.array(
        [ant for ant in data_ants if ant not in bad_ants]
    )
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"File selection took {dt:.2f} minutes.")

    # Now load in the files.
    print("Loading simulation data...")
    t1 = time.time()
    sim_uvdata = UVData()
    # If the simulation data is compressed by redundancy, then we're going to
    # severely mess things up if we remove antenna-based metadata before
    # inflating by redundancy. Otherwise, only load in antennas that have data
    # and remove any extra antenna-based metadata.
    sim_uvdata.read(
        sim_files[first_ind:last_ind+1],
        antenna_nums=None if args.input_is_compressed else ants_to_load,
        keep_all_metadata=args.input_is_compressed,
    )
    if not sim_uvdata.future_array_shapes:
        sim_uvdata.use_future_array_shapes()
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Reading simulation data took {dt:.2f} minutes.")

    # Now interpolate the simulation data to the reference data times.
    print("Interpolating simulation to observed times...")
    t1 = time.time()
    if np.any(ref_lsts > (2 * np.pi)):
        # If the refererence LSTs span the phase wrap,
        # then the simulation LSTs must also span that wrap.
        sim_uvdata.lst_array[sim_uvdata.lst_array < args.lst_wrap] += 2 * np.pi
    sim_uvdata = hera_sim.adjustment.interpolate_to_reference(
        sim_uvdata,
        ref_times=ref_times,
        ref_lsts=ref_lsts,
        axis="time",
        kind="cubic",
        kt=3,
    )
    sim_uvdata.lst_array %= (2 * np.pi)
    ref_integration_time = np.mean(ref_uvdata.integration_time)
    sim_uvdata.integration_time[:] = ref_integration_time
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Interpolating simulation to data took {dt:.2f} minutes.")

    # Inflate the data if it's compressed
    if args.inflate:
        print("Inflating data by redundancy...")
        t1 = time.time()
        sim_uvdata.inflate_by_redundancy()
        t2 = time.time()
        dt = (t2 - t1) / 60
        print(f"Inflating data took {dt:.2f} minutes.")

    # If the input data was compressed, then we need to do the downselect
    # to data-only antennas *after* inflation.
    if args.inflate and args.input_is_compressed:
        sim_uvdata.select(antenna_nums=ants_to_load, keep_all_metadata=False)

    # Now apply the systematics.
    sim_uvdata = Simulator(data=sim_uvdata)

    # For debugging purposes.
    ant_1_array = sim_uvdata.ant_1_array
    ant_2_array = sim_uvdata.ant_2_array
    auto_inds = ant_1_array == ant_2_array
    pols = sim_uvdata.pols
    pol_inds = np.array([pol[0] == pol[1] for pol in pols])
    print("Simulating and applying systematics.")
    print("====================================\n")
    for component_name, parameters in config.items():
        # For testing purposes
        #components_to_simulate = (
            #"short_reflection",
            #"reflection_spectrum",
            #"long_reflection",
            #"mutual_coupling",
        #)
        components_to_simulate = list(config.keys())
        if component_name not in components_to_simulate:
            continue
        t1 = time.time()
        component = parameters.pop("simulator", component_name)
        print(f"Simulating {component_name}:")
        print( "-----------" + "-" * len(component_name))
        print("Parameters:")
        for param, value in parameters.items():
            print(f"    {param} : {value}")
            if isinstance(value, list):
                parameters[param] = np.array(value)
        print("Min/Mean/Max before:")
        for attr in ("min", "mean", "max"):
            print(f"    {getattr(sim_uvdata.data_array, attr)()}")

        autos = sim_uvdata.data_array[auto_inds][...,pol_inds]
        print("Min/Mean/Max of autos before:")
        for attr in ("min", "mean", "max"):
            print(f"    {getattr(autos, attr)()}")


        # Read in the mutual coupling mixing matrix if a file is provided.
        # NOTE: This is tuned to the particular format I used for saving the
        # coupling matrix this time around. A better solution would probably
        # be to use an h5 file and figure out a smart way to slice into the
        # data without needing to actually read the full coupling matrix.
        if component.lower() == "mutualcoupling" and "datafile" in parameters:
            coupling_info = dict(np.load(parameters.pop("datafile")))
            coupling_ants = coupling_info["antenna_numbers"]
            sim_ants = set(sim_uvdata.antenna_numbers)
            _select = np.array([ant in sim_ants for ant in coupling_ants])
            select = np.zeros(2*_select.size, dtype=bool)
            select[::2] = _select
            select[1::2] = _select
            parameters["coupling_matrix"] = (
                coupling_info["coupling_matrix"][...,select,:][...,select]
            )

        sim_uvdata.add(component, component_name=component_name, **parameters)
        print("Min/Mean/Max after:")
        for attr in ("min", "mean", "max"):
            print(f"    {getattr(sim_uvdata.data.data_array, attr)()}")

        autos = sim_uvdata.data_array[auto_inds][...,pol_inds]
        print("Min/Mean/Max of autos after:")
        for attr in ("min", "mean", "max"):
            print(f"    {getattr(autos, attr)()}")

        t2 = time.time()
        dt = t2 - t1
        print(f"Done in {dt:.5f} seconds.\n")

    # NOTE: this should be updated to something more robust in the future,
    # but we're currently in a weird place where the x-orientation in the
    # simulated beam doesn't match what we use in the data, and sometimes
    # the beam files don't actually have an x-orientation set.
    sim_uvdata.data.x_orientation = "east"

    # Now remove antennas that were fully flagged in the real data.
    if set(ants_to_load) != set(ants_to_keep):
        sim_uvdata.data.select(antenna_nums=ants_to_keep, keep_all_metadata=False)

    # We should be done. Now just write the contents to disk.
    t1 = time.time()

    # This is a little bit of a hack to ensure we don't overwrite
    # the file that is linked to.
    if outfile.is_symlink():
        outfile.unlink()
    sim_uvdata.write(
        str(outfile), save_format="uvh5", clobber=args.clobber, fix_autos=True
    )
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Writing data to disk took {dt:.2f} minutes.")
    end_time = time.time()
    runtime = (end_time - init_time) / 60
    print(f"Entire process took {runtime:.2f} minutes.")
