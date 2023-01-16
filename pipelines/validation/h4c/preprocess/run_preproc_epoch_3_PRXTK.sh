#!/bin/bash
#SBATCH --job-name=preprocess_PRXTK_epoch_3
#SBATCH --partition=hera
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=15
#SBATCH --mem=250G
#SBATCH --time=256:00:00
#SBATCH --output=preprocess_PRXTK_epoch_3.out
#SBATCH --export=ALL


source ~/.bashrc
conda activate h1c_idr3_2_validation
cd /lustre/aoc/projects/hera/Validation/test-4.1.0/LSTBIN/epoch_3/preprocess

echo "start: $(date)"
preprocess_dir=/lustre/aoc/projects/hera/Validation/test-4.1.0/software/hera_pipelines/pipelines/validation/h1c_idr3_2/preprocess
${preprocess_dir}/preprocess_data.py ${preprocess_dir}/preprocess_params_epoch_3_PRXTK.yaml 

echo "end: $(date)"
