#!/bin/bash
#SBATCH --job-name=eor_K_pspec
#SBATCH --partition=hera
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --mem=128G
#SBATCH --time=256:00:00
#SBATCH --output=eor_K_pspec.out
#SBATCH --export=ALL

source ~/.bashrc
conda activate h1c_idr3_2_validation
cd /lustre/aoc/projects/hera/Validation/test-4.1.0/LSTBIN/eor_only/all_epochs/pspec

echo "start: $(date)"
pspec_dir=/lustre/aoc/projects/hera/Validation/test-4.1.0/software/hera_pipelines/pipelines/validation/h1c_idr3_2/pspec/
${pspec_dir}/pspec_pipe.py ${pspec_dir}/pspec_params_eor_K.yaml

echo "end: $(date)"
