#!/bin/bash
#SBATCH --job-name=epoch_1_PK_true_sum_preprocess
#SBATCH --partition=hera
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=15
#SBATCH --mem=250G
#SBATCH --time=256:00:00
#SBATCH --output=epoch_1_PK_true_sum_preprocess.out
#SBATCH --export=ALL

source ~/.bashrc
conda activate h1c_idr3_2_validation
cd /lustre/aoc/projects/hera/Validation/test-4.1.0/LSTBIN/true_sum/epoch_1/preprocess

echo "start: $(date)"
preprocess_dir=/lustre/aoc/projects/hera/Validation/test-4.1.0/software/hera_pipelines/pipelines/validation/h1c_idr3_2/preprocess
${preprocess_dir}/preprocess_data.py ${preprocess_dir}/preprocess_params_epoch_1_true_sum_PX.yaml

echo "end: $(date)"
