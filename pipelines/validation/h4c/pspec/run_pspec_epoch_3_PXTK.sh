#!/bin/bash
#SBATCH --job-name=epoch_3_PXTK_pspec
#SBATCH --partition=hera
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=15
#SBATCH --mem=250G
#SBATCH --time=256:00:00
#SBATCH --output=epoch_3_PXTK_pspec.out
#SBATCH --export=ALL

source ~/.bashrc
conda activate h1c_idr3_2_validation
cd /lustre/aoc/projects/hera/Validation/test-4.1.0/LSTBIN/epoch_3/pspec

echo "start: $(date)"
pspec_dir=/lustre/aoc/projects/hera/Validation/test-4.1.0/software/hera_pipelines/pipelines/validation/h1c_idr3_2/pspec/
${pspec_dir}/pspec_pipe.py ${pspec_dir}/pspec_params_epoch_3_PXTK.yaml 

echo "end: $(date)"
