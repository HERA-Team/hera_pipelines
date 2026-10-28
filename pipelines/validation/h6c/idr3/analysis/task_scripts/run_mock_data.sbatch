#!/bin/bash
#SBATCH --job-name=mock_diffuse_2459122
#SBATCH --partition=hera      # e.g. 'defq' or whatever NRAO uses
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G                         # adjust if needed
#SBATCH --time=04:00:00                   # adjust
#SBATCH --output=logs/mock_%j.out
#SBATCH --error=logs/mock_%j.err

module load anaconda/whatever  # if applicable
source /path/to/conda.sh       # if applicable
conda activate <your_hera_env> # the env you set up for this project

# Go to the directory that has do_MOCK_DATA.sh and _common.sh
cd /lustre/aoc/projects/hera/Validation/H6C_IDR2/src/hera_pipelines/pipelines/validation/h6c/analysis/task_scripts

# Call the wrapper with a specific reference file and sky component
./do_MOCK_DATA.sh zen.2459122.12345.sum.uvh5 diffuse

