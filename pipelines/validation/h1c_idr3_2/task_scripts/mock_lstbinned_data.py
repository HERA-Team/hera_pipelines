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
parser.add_argument("ref_file", type=str, help="File to match LSTs, antennas, etc.")
parser.add_argument("sky_cmp", type=str, help="Sky component (e.g. diffuse).")
parser.add_argument("outfile", type=str, help="Path of output file.")
parser.add_argument("--config", type=str, default=None, help="Path to configuration file with systematics. Default None or all white space string means no systematics.")
parser.add_argument("--sim_dir", type=str, default=".", help="Path to directory containing simulation files.")
parser.add_argument("--lst_wrap", type=float, default=4.711094445, help="Where to wrap in LST.")
parser.add_argument("--clobber", default=False, action="store_true", help="Overwrite existing files.")
parser.add_argument("--inflate", default=False, action="store_true", help="Inflate data by redundancy.")
parser.add_argument("--input_is_compressed", default=False, action="store_true", help="Whether the input files are compressed by redundancy.")

if __name__ == "__main__":
    init_time = time.time()
    # Setup
    args = parser.parse_args()

    # Get the perfectly-calibrated simulation files.
    t1 = time.time()
    base_path = Path(args.sim_dir)
    sim_dir = base_path / args.sky_cmp
    lst_re = re.compile("\d+\.\d+")
    def sort(fn):
        return float(lst_re.findall(str(fn))[0])
    sim_files = sorted(sim_dir.glob("*.uvh5"), key=sort)
    start_lsts = np.array(
        [float(lst_re.findall(str(fn))[0]) for fn in sim_files]
    )  # We'll need these later.

    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Setup took {dt:.2f} minutes.")

    # Start the interpolation routine.
    t1 = time.time()
    ref_uvdata = UVData()
    ref_uvdata.read(args.ref_file, read_data=False)
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
    last_ind = np.argwhere(start_lsts <= np.round(ref_lsts.max() + dref_lsts, 7)).flatten()[-1]

    # Before loading in the files, figure out which antennas to select.
    bad_ants = [] # bad ants are assumed to already be excluded from the reference data
    # We need separate antenna arrays since not all of the antennas will be present
    # in the data for compressed files, which can lead to read errors.
    sim_uvdata = UVData()
    sim_uvdata.read(sim_files[0], read_data=False)
    data_ants = set(sim_uvdata.ant_1_array.tolist()).union(
        sim_uvdata.ant_2_array.tolist()
    )
    ants_to_load = np.array(list(data_ants))
    # If we're inflating, then we're going to need to make sure not to include any
    # bad antennas that may have been missed in the previous filter.
    if not args.inflate:
        ants_to_keep = ants_to_load
    else:
        ants_to_keep = np.array([ant for ant in ref_uvdata.antenna_numbers if ant not in bad_ants])

    trim_on_read = set(ants_to_keep.tolist()) == set(ants_to_load.tolist())
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"File selection took {dt:.2f} minutes.")

    # Now load in the files.
    t1 = time.time()
    sim_uvdata = UVData()
    sim_uvdata.read(
        sim_files[first_ind:last_ind+1],
        antenna_nums=ants_to_load,
        keep_all_metadata=not trim_on_read,
    )
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Reading simulation data took {dt:.2f} minutes.")

    # Now interpolate the simulation data to the reference data times.
    t1 = time.time()
    if np.any(ref_lsts > (2 * np.pi)):
    # if the refererence LSTs span the phase wrap, the sim lsts must also span that wrap
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
        t1 = time.time()
        sim_uvdata.inflate_by_redundancy()
        t2 = time.time()
        dt = (t2 - t1) / 60
        print(f"Inflating data took {dt:.2f} minutes.")

    if not trim_on_read:
        sim_uvdata.select(antenna_nums=ants_to_keep, keep_all_metadata=False)

    # Make sure the antennas are ordered the same way as in the configuration file.
    t1 = time.time()
    antnum_diffs = ants_to_keep[:,None] - np.array(sim_uvdata.antenna_numbers)[None,:]
    index_map = np.argwhere(antnum_diffs == 0)[:,1]
    assert np.all(ants_to_keep == np.array(sim_uvdata.antenna_numbers[index_map]))
    sim_uvdata.antenna_numbers = np.array(sim_uvdata.antenna_numbers)[index_map]
    sim_uvdata.antenna_names = np.array(sim_uvdata.antenna_names)[index_map]
    sim_uvdata.antenna_positions = sim_uvdata.antenna_positions[index_map,:]
    sim_uvdata.antenna_diameters = np.array(sim_uvdata.antenna_diameters)[index_map]
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Fixing antenna ordering took {dt:.2f} minutes.")

    # Now apply the systematics.
    sim_uvdata = Simulator(data=sim_uvdata)
    if (isinstance(args.config, str) and len(args.config.strip()) == 0):
        args.config = None
    if args.config is not None:
        config_path = Path(args.config)
        with open(config_path, "r") as cfg:
            config = yaml.load(cfg.read(), Loader=yaml.FullLoader)

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
                print(f"    {getattr(sim_uvdata.data.data_array, attr)()}")
            sim_uvdata.add(component, component_name=component_name, **parameters)
            print("Min/Mean/Max after:")
            for attr in ("min", "mean", "max"):
                print(f"    {getattr(sim_uvdata.data.data_array, attr)()}")
            t2 = time.time()
            dt = t2 - t1
            print(f"Done in {dt:.5f} seconds.\n")

    else:
        print('No config file as provided, so no systematics have been applied.')

    # We should be done. Now just write the contents to disk.
    t1 = time.time()
    sim_uvdata.write(str(args.outfile), save_format="uvh5", clobber=args.clobber)
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Writing data to disk took {dt:.2f} minutes.")
    end_time = time.time()
    runtime = (end_time - init_time) / 60
    print(f"Entire process took {runtime:.2f} minutes.")
