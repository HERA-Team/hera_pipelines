#!/usr/bin/env python
"""Build the mini dataset makeflow, choosing job_stride so that there is about one job per output file.

This finds every single-baseline file in input_folder that matches fname_format in the config, works
out how many output files the averaging settings produce (using the same code as the jobs), sets
job_stride = Nfiles // Noutput_files, writes a copy of the config with that job_stride filled in, and
builds the makeflow on exactly those files.

usage:
    python build_mini_dataset_makeflow.py mini_dataset.toml /path/to/single_bl_folder [--work_dir DIR] [--mf_name NAME]
"""
import argparse
import os
import re
import sys

import numpy as np
import toml

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "task_scripts"))
from make_mini_dataset import build_output_chunks, get_time_grid, list_input_files  # noqa: E402
from hera_opm import mf_tools  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("config", help="Path to the mini dataset config (e.g. mini_dataset.toml).")
    parser.add_argument("input_folder", help="Folder containing the single-baseline files to average.")
    parser.add_argument("--work_dir", default=None, help="Where to write the makeflow, wrapper scripts, logs, and the config "
                                                         "with job_stride filled in. Default: the current directory.")
    parser.add_argument("--mf_name", default=None, help="Name of the makeflow file. Default: <config name>.mf")
    args = parser.parse_args()

    opts = toml.load(args.config)["MINI_DATASET_OPTS"]
    lst_range = None if str(opts["lst_range"]) == "None" else [float(x) for x in str(opts["lst_range"]).split(",")]

    input_folder = os.path.abspath(args.input_folder)
    files, _, _, file_regex = list_input_files(input_folder, opts["fname_format"])
    if len(files) == 0:
        raise ValueError(f"No files in {input_folder} match fname_format = {opts['fname_format']}")
    times, lsts = get_time_grid(files[0])
    chunks = build_output_chunks(times, lsts, int(opts["ints_to_average"]), int(opts["ints_per_output_file"]), lst_range)
    if len(chunks) == 0:
        raise ValueError("These settings produce no output files. Check lst_range and ints_to_average.")
    job_stride = max(1, len(files) // len(chunks))
    n_jobs = int(np.ceil(len(files) / job_stride))

    # write a copy of the config with job_stride filled in
    with open(args.config) as f:
        config_text = f.read()
    config_text, n_subs = re.subn(r"(?m)^job_stride\s*=.*$",
                                  f"job_stride = {job_stride}  # set by build_mini_dataset_makeflow.py for "
                                  f"{len(files)} input files and {len(chunks)} output files",
                                  config_text)
    if n_subs != 1:
        raise ValueError(f"Expected exactly one 'job_stride = ...' line in {args.config}, found {n_subs}.")
    work_dir = os.path.abspath(args.work_dir if args.work_dir is not None else os.getcwd())
    os.makedirs(work_dir, exist_ok=True)
    config_stem = os.path.splitext(os.path.basename(args.config))[0]
    resolved_config = os.path.join(work_dir, f"{config_stem}.job_stride_{job_stride}.toml")
    with open(resolved_config, "w") as f:
        f.write(config_text)

    mf_name = args.mf_name if args.mf_name is not None else f"{config_stem}.mf"
    mf_tools.build_makeflow_from_config(files, resolved_config, mf_name=mf_name, work_dir=work_dir)

    print(f"Found {len(files)} files in {input_folder} matching {file_regex.pattern}, each with {len(times)} integrations.")
    print(f"These make {len(chunks)} output files in {os.path.join(input_folder, str(opts['out_folder']))}.")
    print(f"Using job_stride = {job_stride}: {n_jobs} jobs, writing up to {int(np.ceil(len(chunks) / n_jobs))} output file(s) each.")
    print(f"Wrote {resolved_config} and {os.path.join(work_dir, mf_name)}.")


if __name__ == "__main__":
    main()
