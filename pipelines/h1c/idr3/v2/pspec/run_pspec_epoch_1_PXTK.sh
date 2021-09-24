#!/bin/bash
#PBS -q hera
#PBS -j oe
#PBS -o pspec_pipe_PXTK_e1.out
#PBS -N pspec_pipe_PXTK_e1
#PBS -l nodes=1:ppn=15
#PBS -l walltime=96:00:00
#PBS -l vmem=250GB,mem=250GB
#PBS -M jsdillon+nrao@berkeley.edu

source ~/.bashrc
conda activate h1c_idr3
cd /lustre/aoc/projects/hera/H1C_IDR3/IDR3_2/LSTBIN/epoch_1/pspec

echo "start: $(date)"
pspec_dir=/lustre/aoc/projects/hera/H1C_IDR3/IDR3_2/h1c_idr3_software/hera_pipelines/pipelines/h1c/idr3/v2/pspec/
${pspec_dir}/pspec_pipe.py ${pspec_dir}/pspec_params_epoch_1_PXTK.yaml 

echo "end: $(date)"
