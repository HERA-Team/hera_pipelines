#!/bin/bash
#PBS -q hera
#PBS -j oe
#PBS -o second_round_lstbin.out
#PBS -N second_round_lstbin
#PBS -l nodes=1:ppn=1
#PBS -l walltime=24:00:00
#PBS -l vmem=64GB,mem=64GB
#PBS -M jsdillon+nrao@berkeley.edu
#PBS -t 1-67%16

source ~/.bashrc
conda activate h1c_idr3

echo "start: $(date)"
lstbin_src_dir=/lustre/aoc/projects/hera/H1C_IDR3/IDR3_2/h1c_idr3_software/hera_pipelines/pipelines/h1c/idr3/v2/lstbin
${lstbin_src_dir}/second_round_lstbin.py ${lstbin_src_dir}/second_round_lstbin.yaml ${PBS_ARRAYID}

echo "end: $(date)"
