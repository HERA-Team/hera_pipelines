#!/bin/bash
#PBS -q hera
#PBS -j oe
#PBS -o preproc_pipe.out
#PBS -N preproc_pipe
#PBS -l nodes=1:ppn=8
#PBS -l walltime=64:00:00
#PBS -l vmem=128GB,mem=128GB
#PBS -M nkern@berkeley.edu

source ~/.bashrc
conda activate hera3
cd /lustre/aoc/projects/hera/H1C_IDR2/IDR2_2_pspec/v2/one_group

echo "start: $(date)"
/users/heramgr/hera_software/H1C_IDR2/pipeline/preprocess_data.py preprocess_params.yaml 

echo "end: $(date)"
