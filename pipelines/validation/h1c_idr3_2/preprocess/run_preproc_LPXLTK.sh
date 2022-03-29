#!/bin/bash
#SBATCH --job-name=LPXLTK_preprocess
#SBATCH --partition=hera
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=15
#SBATCH --mem=250G
#SBATCH --time=256:00:00
#SBATCH --output=LPXLTK_preprocess.out
#SBATCH --export=ALL

source ~/.bashrc
conda activate h1c_idr3_2_validation
cd /lustre/aoc/projects/hera/Validation/test-4.1.0/LSTBIN/all_epochs_preprocessed/preprocess

echo "start: $(date)"
preprocess_dir=/lustre/aoc/projects/hera/Validation/test-4.1.0/software/hera_pipelines/pipelines/validation/h1c_idr3_2/preprocess
${preprocess_dir}/preprocess_data.py ${preprocess_dir}/preprocess_params_LPXLTK.yaml

echo "end: $(date)"
