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

if __name__ == "__main__":
    print('making mock data...')
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
    last_ind = np.argwhere(start_lsts <= np.round(ref_lsts.max() + dref_lsts, 7)).flatten()[-1]

    # Before loading in the files, figure out which antennas to select.
    # NOTE: this is updated for H4C, but I still don't like that it's hardcoded.
    # A better solution might be to have the user provide a path to the files with
    # the a-priori flagging info, but the convention for storing this data changed
    # between H1C (text file) and H4C (yaml file).
    h4c_path = Path("/lustre/aoc/projects/hera/H4C")
    pipeline_path = h4c_path / "h4c_software/hera_pipelines/pipelines/h4c/rtp/v2"
    flag_file = pipeline_path / f"stage_2_a_priori_flags_include_variable/{jd}.yaml"
    with open(flag_file, "r") as flag_info:
        bad_ants = np.array(
            yaml.load(flag_info.read(), Loader=yaml.SafeLoader)["ex_ants"]
        ).astype(int)

    # We need separate antenna arrays since not all of the antennas will be present
    # in the data for compressed files, which can lead to read errors.
    sim_uvdata = UVData()
    sim_uvdata.read(sim_files[0], read_data=False)
    data_ants = set(sim_uvdata.ant_1_array.tolist()).union(
        sim_uvdata.ant_2_array.tolist()
    )
    ants_to_load = np.array(
        [ant for ant in data_ants if ant not in bad_ants]
    ) if not args.input_is_compressed else np.array(list(data_ants))

    # If we're inflating, then we're going to need to make sure not to include any
    # bad antennas that may have been missed in the previous filter.
    ants_to_keep = np.array(
        [ant for ant in ref_uvdata.antenna_numbers if ant not in bad_ants]
    )
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
    if not sim_uvdata.future_array_shapes:
        sim_uvdata.use_future_array_shapes()
    print('using future array shape:', sim_uvdata.future_array_shapes)
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
        print('using future array shape:', sim_uvdata.future_array_shapes)
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

        print("I am the new version I swear!! Bobby swears too!")

        # Read in the mutual coupling mixing matrix if a file is provided.
        # NOTE: This is tuned to the particular format I used for saving the
        # coupling matrix this time around. A better solution would probably
        # be to use an h5 file and figure out a smart way to slice into the
        # data without needing to actually read the full coupling matrix.
        if component.lower() == "mutualcoupling" and "datafile" in parameters:
            coupling_info = dict(np.load(parameters.pop("datafile")))
            coupling_ants = np.sort(np.unique(coupling_info["ant_1_array"]))
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

    # We should be done. Now just write the contents to disk.
    t1 = time.time()

    # This is a little bit of a hack to ensure we don't overwrite
    # the file that is linked to.
    if outfile.is_symlink():
        outfile.unlink()
    sim_uvdata.write(str(outfile), save_format="uvh5", clobber=args.clobber)
    t2 = time.time()
    dt = (t2 - t1) / 60
    print(f"Writing data to disk took {dt:.2f} minutes.")
    end_time = time.time()
    runtime = (end_time - init_time) / 60
    print(f"Entire process took {runtime:.2f} minutes.")
