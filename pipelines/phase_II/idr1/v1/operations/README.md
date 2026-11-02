# Phase II IDR1 v1 night operations

How the nights of `../analysis/phase_II_analysis.toml` are run, by the manager in [`operations/`](../../../../../operations/)
at the top of this repo (its README covers running it, its keys, and what to do when things go wrong):

```bash
python operations/tui.py --config pipelines/phase_II/idr1/v1/operations/config.toml
```

Before the first night: fill in the `[paths]` in `config.toml`, check its `[limits]`, put the nights to process
in `nights.txt`, and list any raw files to leave out in `excluded_files.txt`.

## A night's steps

| step | script | what it does |
|---|---|---|
| stage | `stage.sh` | `librarian stage-files -w` the night's sum files into `{raw_root}/{JD}/`, with its diff files (before JD 2460039) or else RTP's antenna classifications (see below), and checks that they arrived |
| build | `build.sh` | links the raw files into `{nights_root}/{JD}/` (but those `excluded_files.txt` leaves out), checks that each sum has its diff, builds the makeflow in `{makeflow_root}/{JD}/`, and records what it was built from and what it left out in `provenance.txt` |
| run | `operations/scripts/run.sh` | `makeflow_nrao.sh`. Running it again resumes the makeflow. The makeflow's last job, CLEANUP (`do_CLEANUP.sh`), bundles the night's intermediates into `{JD}_*.tar.gz` files |
| *review* | (you) | look at the night's notebooks (listed in the TUI), then approve it (`y`) or hold it (`h`) |
| prune | `prune.sh` | bundles the makeflow folder's wrappers and logs, and deletes the files the CLEANUP bundles were made from and the products not worth keeping, the raw data among them |
| archive | `operations/scripts/archive.sh` | copies the night's folder and makeflow folder to `{cold_root}/{JD}_analysis/`, checks the copy, then deletes the bundles from Lustre |

## RTP antenna classifications

Diffs were only recorded through H6C, so on later nights the sky calibration notebook reads RTP's antenna
classification of each file (`zen.{JD}.{decimal}.sum.rtp_ant_class.csv`) instead. Stage gets them from the
librarian either as they are, or (failing that) as RTP has uploaded them since H6C (its
`do_LIBRARIAN_CALIBRATION_NOTEBOOKS.sh`): one tarball per night of its `zen.{JD}.{decimal}.sum.ant_class.csv`
files, named for the night's first file (`zen.{JD}.{decimal}.sum.ant_class.csv.tar.gz`). It unpacks the tarball and
renames each file `.rtp_ant_class.csv`, so RTP's files can't be mistaken for the `ant_class.csv` files this
pipeline makes itself.

## Leaving files out

`excluded_files.txt` lists the raw files to leave out of their nights, a line for each night (or for each reason in
a night): `{JD}  {decimal} {decimal} ...  # why`. Each is still staged (and prune deletes its staged copy with the
rest), but build never links it into the night's folder, so neither the makeflow nor anything that looks through the
folder ever sees it. Build stops if an entry names a file that wasn't staged, and if a sum has no partner (its diff,
or on nights without diffs its RTP antenna classification) or a diff no sum, naming them so you can add them to the
list.

To leave a file out of a night that has already been built, add it to the list and reset the night from build
(`R` in the TUI). Once the night's makeflow has run, that means deleting its makeflow folder first, and build also
stops until you have deleted any products in the night's folder made from that file (`zen.{JD}.{decimal}.*`).

## What's kept, archived, and deleted

That is up to the toml: every product in its `[DATA_PRODUCTS]` that is in a night's folder (what the workflow
writes, and the raw data linked into it) has a `retention`.

- **`archive`** (the calibration solutions and metrics, the per-file flags, and the SNRs): the CLEANUP job bundles
  each product into `{JD}_<NAME>.tar.gz` beside its files, and lists the files in a `.contents.txt`. Prune deletes
  the files, but only those that haven't changed since. Archive moves the bundle to cold storage, and the
  `.contents.txt` stays behind as a record. The rendered notebooks are bundled the same way.
- **`delete`** (the raw sum and diff files and RTP antenna classifications, the per-file redundant averages, and
  their corner turn): prune deletes them, both from the night's folder (where the raw data are links) and their
  staged copies in `{raw_root}/{JD}/`. The librarian keeps the raw data, and the rest is large and remade from them.
- **`keep`** (the inpainted data, where_inpainted, the inpaint covariance, every round's flags, the source models,
  the corner-turn map, and the a posteriori flags): they stay on Lustre, and archive copies them to cold storage too.

A product in the night's folder with no `retention` fails CLEANUP, and CLEANUP (or prune) also stops if a file it
would bundle (or delete) matches another product's pattern too. `task_scripts/data_products.py` says how each
product's files are found. At the end, prune warns about any file left in the night's folder that no product
declares, since archive copies it to cold storage like the rest.

## Testing

`pytest pipelines/phase_II/idr1/v1/operations/tests` runs these steps on fake nights, with `tests/fake_products.sh`
standing in for what the makeflow makes, and checks the retention of every product in the toml.
`bash operations/tests/demo.sh --pipeline pipelines/phase_II/idr1/v1/operations` starts the TUI on fake nights of
this pipeline.

## Still to settle

- What `librarian stage-files -w` does when nothing matches its pattern, which it meets on every night without diffs
  whose RTP antenna classifications are only in RTP's tarball. Stage carries on to the tarball either way, but check
  that it doesn't wait forever on the first such night.
