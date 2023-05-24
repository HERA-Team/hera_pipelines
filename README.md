# hera_pipelines

Repo for saving HERA workflow pipelines and management scripts.


## Contents

All of the DO-scripts and makeflow files are in the [pipelines](pipelines/) directory.
Each season has its own subfolder here.

The repo also contains an installable package, [hera_pipelines](src.hera_pipelines/),
which contains a CLI for managing files and running pipelines in idiomatic ways.

## Installation

``pip install git+https://github.com/HERA-Team/hera_pipelines``

## Usage

The package provides a CLI for managing files and running pipelines in idiomatic ways.
Once installed, the CLI can be accessed by running ``herapipes`` from anywhere. To get
a list of subcommands, use

```bash
herapipes --help
```

As an example, to extract autos into their own files for an entire directory of
sum/diff files:

```bash
herapipes fix-autos .
```
