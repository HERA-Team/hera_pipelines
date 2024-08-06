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

### Setting up LST-bin pipeline TOML's.

We run a number of different cases of LST-binning, with different parameters set. To 
ensure we run each different cases with consistent parameters for those that *don't*
change, we set up the TOML pipelines via the CLI.

The logic for setting this up is in the `cli.lstbin_setup` function. It is envisaged that
this logic will need to be updated for each new IDR (and perhaps each new generation).
The point is not to make this function flexible enough to handle all possible cases over
all releases, but instead just to have a tool to enable defining the TOML for a given
release. There is a *template* TOML in the `pipelines/SEASON/IDR/GEN/lstbin/` directory
called `lstbin-template.toml` (e.g. `pipelines/h6c/idr2/v3/lstbin/lstbin-template.toml`).
This template should set all the parameters that remain the same between cases for this
particular IDR/GENERATION. It is defined as a Jinja2 template, and can receive parameters
from the CLI (the parameters it receives are listed at the top of the template, and you 
can add more by modifying the CLI function). 

When run, the CLI function will create one instance of the TOML file for each "case"
of lst-binning (e.g. `redavg-smoothcal-inpaint-500ns-lstcal`), and write this file to a
subdirectory called by that case name *inside this repo*. The general process of defining
the TOMLs in production is envisaged to be the following:

1. Define the cases you want to produce in the `cli` module (and adjust any logic to go
   with it).
2. Run the command from within the repo, e.g.: 
   `herapipes lstbin-setup --all-cases --force --season h6c --idr 2 --gen 3`.
   This creates the actual TOML files within the repo, *and* creates symlinks to these 
   files in the analysis directory if you're on lustre. 
1. Check that the files look reasonable and then *commit* them to the repository (and
   push them), so we have a single set-in-stone version of them within git for future
   reference.