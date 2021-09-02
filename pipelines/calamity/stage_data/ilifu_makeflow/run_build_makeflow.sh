#!/bin/bash

source $CONDA_INIT_SCRIPT
conda activate calamity
cd /disc/ilifu/astro/projects/hera/aewallwi/mwa/makeflow/
build_makeflow_from_config.py -c /disc/ilifu/astro/projects/hera/aewallwi/hera_pipelines/pipelines/calamity/stage_data/stage_data.toml /disc/ilifu/astro/projects/her
a/aewallwi/mwa/*.metafits
