#!/bin/bash
#SBATCH --job-name=P_second_round_lst_bin
#SBATCH --partition=hera
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=P_second_round_lst_bin.out
#SBATCH --export=ALL
#SBATCH --array=1-67%32

source ~/.bashrc
conda activate h1c_idr3

echo "start: $(date)"
lstbin_src_dir=/lustre/aoc/projects/hera/Validation/test-4.1.0/software/hera_pipelines/pipelines/validation/h1c_idr3_2/lstbin
${lstbin_src_dir}/second_round_lstbin.py ${lstbin_src_dir}/second_round_lstbin_P.yaml ${SLURM_ARRAY_TASK_ID}

echo "end: $(date)"
