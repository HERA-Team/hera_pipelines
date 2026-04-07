"""Build the baseline_map.yaml consumed by the single-baseline LST stack pipeline.

This script is invoked once per makeflow invocation by the SETUP action. It
produces a single YAML file at ``${LST_STACK_OPTS.OUTDIR}/baseline_map.yaml``
that freezes, for every baseline string in the configurator's bl_to_file_map:

    - ``bl_length_m``        : baseline length in meters
    - ``avg_redundancy``     : mean over nights of the size of this bl's
                               redundant group, computed from per-JD CSVs
                               and aposteriori flag YAMLs (no data reads)
    - ``in_preliminary_set`` : this bl (or its reverse orientation) is one of
                               the top-NBLS_FOR_LSTCAL baselines by
                               ``(avg_redundancy desc, bl_str asc)`` drawn
                               from the viable pool (short enough to lstcal
                               on and present on every night)
    - ``night_for_lstcal``   : which JD (int) this bl anchors for single-night
                               LST-cal dispatch, or ``None`` if it isn't an
                               anchor. Anchors are the top ``len(nights)``
                               viable canonical bls by
                               ``(avg_redundancy desc, bl_str asc)``, zipped
                               1:1 against ``sorted(nights)``.

The YAML intentionally contains NO decision about whether a baseline makes
it into the final SINGLE_BASELINE_LSTSTACK run. That decision is made at
script time in ``do_SINGLE_BASELINE_LSTSTACK.sh`` by thresholding
``bl_length_m`` and/or ``avg_redundancy`` against TOML parameters, so the
TOML can be edited without regenerating this YAML.

All sorting is done on explicit tuple keys with no ``set()``-to-``list``
conversion, so the output is deterministic (byte-identical) across runs with
different ``PYTHONHASHSEED`` values. If the viable pool has fewer than
``len(nights)`` canonical baselines the script raises loudly — no silent
truncation.
"""

import argparse
import glob
import os

import numpy as np
import pandas as pd
import toml
import yaml

from hera_cal import io, lst_stack, red_groups
from hera_qm.metrics_io import read_a_priori_ant_flags


def _canonical_bl_key(bl_str):
    """Return (min_ant, max_ant) so reverse orientations collapse together."""
    a, b = (int(x) for x in bl_str.split("_"))
    return (a, b) if a <= b else (b, a)


def build_baseline_map(toml_file):
    configurator = lst_stack.config.LSTBinConfiguratorSingleBaseline.from_toml(toml_file)
    toml_config = toml.load(toml_file)

    nbls_for_lstcal = toml_config["LSTCAL_OPTS"]["NBLS_FOR_LSTCAL"]
    outdir = toml_config["LST_STACK_OPTS"]["OUTDIR"]

    # antpos from one data file (same pattern used by the old
    # use_baseline_for_lstcal.py / check_baseline_length.py)
    sample_bl = sorted(configurator.bl_to_file_map.keys())[0]
    hd = io.HERAData(configurator.bl_to_file_map[sample_bl][0])
    antpos = hd.antpos

    # ----- redundancy-per-night computation (from use_baseline_for_lstcal.py) -----
    jds = [int(night) for night in configurator.nights]
    filepath = toml_config["FILE_CFG"]["datafiles"]["datadir"]
    aposteriori_yamls = {jd: os.path.join(filepath, f"{jd}/{jd}_aposteriori_flags.yaml") for jd in jds}

    data_antpos = {}
    per_jd_ex_ants = {}
    for jd in jds:
        csvs = sorted(glob.glob(os.path.join(filepath, f"{jd}/*.csv")))
        antenna_strings = pd.read_csv(csvs[0], usecols=["Antenna"])["Antenna"]
        data_ants = antenna_strings.str.extract(r"(\d+)")[0].astype(int).unique().tolist()
        data_antpos.update({ant: antpos[ant] for ant in data_ants})
        per_jd_ex_ants[jd] = set(read_a_priori_ant_flags(aposteriori_yamls[jd]))

    jd_keys = sorted(per_jd_ex_ants.keys())
    shared_ex_ants = set(per_jd_ex_ants[jd_keys[0]]).intersection(
        *[per_jd_ex_ants[jd] for jd in jd_keys[1:]]
    )
    unique_ex_ants = {
        jd: sorted(set(per_jd_ex_ants[jd]).difference(shared_ex_ants)) for jd in jd_keys
    }

    all_reds = red_groups.RedundantGroups.from_antpos(
        antpos=antpos, pols=("nn", "ee"), include_autos=False
    )
    filtered_reds = red_groups.RedundantGroups.from_antpos(
        antpos=data_antpos, pols=("nn", "ee"), include_autos=False
    )
    filtered_reds.filter_reds(inplace=True, ex_ants=sorted(shared_ex_ants))

    # per-JD redundant-group-size lookup keyed by the all-array ubl key
    per_jd_group_size = {}
    for jd in jds:
        reds = filtered_reds.filter_reds(inplace=False, ex_ants=unique_ex_ants[jd])
        per_jd_group_size[jd] = {
            all_reds.get_ubl_key(red[0]): len(red) for red in reds
        }

    # mean redundancy for each (min_ant, max_ant) pair across nights. We key by
    # the sorted antpair so the lookup works regardless of whatever canonical
    # orientation RedundantGroups picked. Nights on which the group has
    # collapsed entirely (key absent from per_jd_group_size[jd]) contribute
    # zero to the mean rather than disqualifying the baseline outright, so a
    # baseline missing from a handful of nights still gets a meaningful
    # (just smaller) avg_redundancy.
    avg_redundancy_by_canonical = {}
    for red in all_reds:
        key_full = red[0]  # (ant1, ant2, pol)
        canonical = tuple(sorted(key_full[:2]))
        per_night_sizes = [per_jd_group_size[jd].get(key_full, 0) for jd in jds]
        avg = float(np.mean(per_night_sizes))
        avg_redundancy_by_canonical.setdefault(canonical, {})[key_full[2]] = avg

    # Collapse per-pol into a single avg_redundancy by averaging the two pols.
    # A pol that dies on every night contributes zero (via the .get above) and
    # pulls the mean down rather than disqualifying the baseline.
    avg_redundancy_final = {
        canonical: float(np.mean(list(per_pol.values())))
        for canonical, per_pol in avg_redundancy_by_canonical.items()
    }

    # ----- per-bl_string entries -----
    bl_entries = {}
    for bl_str in sorted(configurator.bl_to_file_map.keys()):
        a, b = (int(x) for x in bl_str.split("_"))
        length = float(np.linalg.norm(antpos[b] - antpos[a]))
        canonical = _canonical_bl_key(bl_str)
        avg_red = float(avg_redundancy_final.get(canonical, 0.0))
        bl_entries[bl_str] = {
            "bl_length_m": length,
            "avg_redundancy": avg_red,
            "in_preliminary_set": False,  # filled in below
            "night_for_lstcal": None,     # filled in below
        }

    # ----- canonical representative per (min_ant, max_ant) pair -----
    # Multiple bl_strs can map to the same physical baseline via reverse
    # orientation; pick a single representative (prefer "a_b" with a<=b if
    # present, else fall back to the reversed orientation).
    canonical_representative = {}
    for bl_str in sorted(bl_entries.keys()):
        canonical = _canonical_bl_key(bl_str)
        a, b = (int(x) for x in bl_str.split("_"))
        is_canonical_orientation = a <= b
        if canonical not in canonical_representative:
            canonical_representative[canonical] = bl_str
        elif is_canonical_orientation and not (
            int(canonical_representative[canonical].split("_")[0])
            <= int(canonical_representative[canonical].split("_")[1])
        ):
            # upgrade to the canonical orientation
            canonical_representative[canonical] = bl_str

    # Viable pool for lstcal anchors / preliminary set: canonical reps with
    # nonzero avg_redundancy. Zero means both pols were empty on every night,
    # so there's nothing to calibrate on. No length gate here — anchor/prelim
    # selection is driven purely by redundancy.
    viable_reps = sorted(
        (
            rep
            for rep in canonical_representative.values()
            if bl_entries[rep]["avg_redundancy"] > 0
        ),
        key=lambda bl_str: (-bl_entries[bl_str]["avg_redundancy"], bl_str),
    )

    # ----- in_preliminary_set: top-NBLS_FOR_LSTCAL canonical pairs -----
    selected_canonical = {
        _canonical_bl_key(rep) for rep in viable_reps[:nbls_for_lstcal]
    }
    for bl_str, entry in bl_entries.items():
        if _canonical_bl_key(bl_str) in selected_canonical:
            entry["in_preliminary_set"] = True

    # ----- night_for_lstcal: top len(nights) viable reps, zipped with sorted(nights) -----
    sorted_nights = sorted(int(n) for n in configurator.nights)
    if len(viable_reps) < len(sorted_nights):
        raise RuntimeError(
            f"Only {len(viable_reps)} viable canonical baselines available, "
            f"but {len(sorted_nights)} nights need anchors."
        )
    for jd, bl_str in zip(sorted_nights, viable_reps[: len(sorted_nights)]):
        bl_entries[bl_str]["night_for_lstcal"] = int(jd)

    # ----- write YAML -----
    output = {
        "_meta": {
            "toml_file": os.path.abspath(toml_file),
            "n_nights": len(sorted_nights),
            "n_baselines": len(bl_entries),
            "nbls_for_lstcal": int(nbls_for_lstcal),
        },
    }
    # put bl entries in sorted order for a byte-stable YAML
    for bl_str in sorted(bl_entries.keys()):
        output[bl_str] = bl_entries[bl_str]

    os.makedirs(outdir, exist_ok=True)
    yaml_path = os.path.join(outdir, "baseline_map.yaml")
    with open(yaml_path, "w") as f:
        yaml.safe_dump(output, f, sort_keys=False, default_flow_style=False)
    print(f"Wrote {yaml_path} "
          f"({len(bl_entries)} baselines, {len(sorted_nights)} nights, "
          f"{len(selected_canonical)} canonical in preliminary set)")
    return yaml_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("toml_file", help="path to the single_bl_lst_stack TOML file")
    args = parser.parse_args()
    build_baseline_map(args.toml_file)
