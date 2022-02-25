"""Write the simulated gains to disk for a particular day."""
import argparse
import hera_sim
import yaml
from pathlib import Path
from pyuvdata import UVData, UVCal

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("jd", type=int, help="Day to simulate gains for.")
parser.add_argument("outfile", type=str, help="Name of the output file.")
parser.add_argument(
    "--include_bandpass",
    action="store_true",
    default=False,
    help="Whether to simualte the bandpass gains.",
)
parser.add_argument(
    "--include_reflections",
    action="store_true",
    default=False,
    help="Whether to simulate the reflection gains.",
)
parser.add_argument(
    "--clober", action="store_true", default=False, help="Whether to overwrite files."
)

if __name__ == "__main__":
    args = parser.parse_args()
    if not (args.include_bandpass or args.include_reflections):
        sys.exit("Nothing to do.")

    # Pull the configuration file for this particular day.
    validation_dir = Path("/lustre/aoc/projects/hera/Validation/H1C_IDR3")
    config_file = validation_dir / f"configs/{args.jd}.yaml"
    with open(config_file, "r") as config:
        full_config = yaml.load(config.read(), Loader=yaml.FullLoader)

    # Figure out exactly what frequencies we need to use.
    data_files = validation_dir / "chunked_data/diffuse"
    data_file = list(data_files.glob("*.uvh5"))[0]
    uvdata = UVData()
    uvdata.read(data_file, read_data=False)
    freqs = uvdata.freq_array.squeeze() / 1e9

    # Figure out which antennas we're using and prepare the gain dictionary.
    antenna_numbers = list(full_config["mutual_coupling"]["cable_delays"].keys())
    gains = dict.fromkeys(antenna_numbers, np.ones_like(freqs, dtype=complex))

    # Simulate the bandpass if asked to do so.
    if args.include_bandpass:
        np.random.seed(full_config["bandpass"]["seed"])
        bandpass_gains = hera_sim.sigchain.Bandpass()(freqs, antenna_numbers)
        for ant, gain in bandpass_gains.items():
            gains[ant] *= gain

    # Prepare references to the classes that simulate reflections.
    reflection_sims = {
        "reflections": hera_sim.sigchain.Reflections,
        "reflection_spectrum": hera_sim.sigchain.ReflectionSpectrum,
    }

    # Simulate the reflections if asked to do so.
    if args.include_reflections:
        for key in ("short_reflection", "long_reflection", "reflection_spectrum"):
            params = full_config.get(key, None)
            if params is None:
                continue
            seed = params.pop("seed")
            simulator = params.pop("simulator", key)
            reflections = reflection_sims[simulator](**params)
            reflection_gains = reflections(freqs, antenna_numbers)
            for ant, gain in reflection_gains.items():
                gains[ant] *= gain

    # Update the keys of the gain dictionary to what the write function expects.
    true_gains = {}
    for ant, gain in gains.items():
        true_gains[(ant, 'x')] = gain
        true_gains[(ant, 'y')] = gain

    # The writer also needs a time array, so let's make a simple one.
    times = np.array([args.jd], dtype=float)
    
    # Now write the gains to disk.
    hera_sim.cli_utils.write_calfits(
        gains=true_gains,
        filename=args.outfile,
        freqs=freqs*1e9,
        times=times,
        x_orientation='e',
        clobber=args.clobber,
    )
    )

