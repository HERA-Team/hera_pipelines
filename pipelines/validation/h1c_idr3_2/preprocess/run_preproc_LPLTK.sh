#!/bin/bash
#PBS -q hera
#PBS -j oe
#PBS -o preproc_LPLTK.out
#PBS -N preproc_LPLTK
#PBS -l nodes=1:ppn=15
#PBS -l walltime=256:00:00
#PBS -l vmem=250GB,mem=250GB
#PBS -M jsdillon+nrao@berkeley.edu

source ~/.bashrc
conda activate h1c_idr3
cd /lustre/aoc/projects/hera/H1C_IDR3/IDR3_2/LSTBIN/all_epochs_preprocessed/preprocess

echo "start: $(date)"
preprocess_dir=/lustre/aoc/projects/hera/H1C_IDR3/IDR3_2/h1c_idr3_software/hera_pipelines/pipelines/h1c/idr3/v2/preprocess
${preprocess_dir}/preprocess_data.py ${preprocess_dir}/preprocess_params_LPLTK.yaml

echo "end: $(date)"
