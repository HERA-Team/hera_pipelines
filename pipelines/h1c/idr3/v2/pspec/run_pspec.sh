#!/bin/bash
#PBS -q hera
#PBS -j oe
#PBS -o pspec_pipe.out
#PBS -N pspec_pipe
#PBS -l nodes=1:ppn=8
#PBS -l walltime=96:00:00
#PBS -l vmem=122GB,mem=122GB
#PBS -M nkern@berkeley.edu

source ~/.bashrc
conda activate hera3
cd /lustre/aoc/projects/hera/H1C_IDR2/IDR2_2_pspec/v2/one_group

echo "start: $(date)"
/users/heramgr/hera_software/H1C_IDR2/pipeline/pspec_pipe.py pspec_params.yaml

echo "end: $(date)"
