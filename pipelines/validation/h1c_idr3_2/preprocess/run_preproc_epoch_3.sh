#!/bin/bash
#PBS -q hera
#PBS -j oe
#PBS -o e3_preproc_pipe.out
#PBS -N e3_preproc_pipe
#PBS -l nodes=1:ppn=15
#PBS -l walltime=256:00:00
#PBS -l vmem=250GB,mem=250GB
#PBS -M jsdillon+nrao@berkeley.edu

source ~/.bashrc
conda activate h1c_idr3
cd /lustre/aoc/projects/hera/H1C_IDR3/IDR3_2/LSTBIN/epoch_3/preprocess

echo "start: $(date)"
preprocess_dir=/lustre/aoc/projects/hera/H1C_IDR3/IDR3_2/software/hera_pipelines/pipelines/validation/h1c_idr3_2/preprocess
${preprocess_dir}/preprocess_data.py ${preprocess_dir}/preprocess_params_epoch_3.yaml 

echo "end: $(date)"
