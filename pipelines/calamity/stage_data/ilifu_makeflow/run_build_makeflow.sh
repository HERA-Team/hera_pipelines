#!/bin/bash

source $CONDA_INIT_SCRIPT
conda activate calamity
cd /ilifu/astro/projects/hera/aewallwi/calamity/makeflow/
build_makeflow_from_config.py -c /ilifu/astro/projects/hera/aewallwi/hera_pipelines/pipelines/calamity/stage_data/stage_data.toml /ilifu/astro/projects/hera/aewallwi/calamity/mwa/*.metafits
