#! /bin/bash
set -e

# This script generates a notebook that processes a single-baseline file, typically redundantly-averaged and
# LST-binned, through to power spectra

src_dir="$(dirname "$0")"
source ${src_dir}/_common.sh

# Parameters are set in the configuration file. Here we define their positions,
# which must be consistent with the config.
# 1 - (raw) filename
# 2+ - various settings
fn=${1}
toml_file=${2}
toml_section=${3}
kernel=${4}
nb_output_repo=${5}

# --variables used by the notebook
outdir=$(cd "$(dirname "$fn")" && pwd)
full_file_path="$outdir/$(basename "$fn")"
echo "Performing single baseline postprocessing and power spectrum estimation on ${full_file_path}"


# check if file is not just autocorrelaitons and that neither polarization is fully flagged
if python ${src_dir}/check_single_bl_file.py ${full_file_path} --skip_autos --skip_outriggers; then
    # Execute jupyter notebook
    nb_outfile=${full_file_path%.uvh5}.single_baseline_postprocessing_and_pspec
    
    runopts="--output-dir ${outdir} -k ${kernel} --toml ${toml_file} --toml-section ${toml_section}"
    cfg="--basename ${nb_outfile} --SINGLE-BL-FILE ${full_file_path} --OUT-PSPEC-FILE=${full_file_path%.uvh5}.pspec.h5"
    echo "Runopts: ${runopts}"
    echo "Config: ${cfg}"

    cmd="hnote run ${runopts} single_baseline_postprocessing_and_pspec ${cfg}"
    echo $cmd
    eval $cmd

    echo Finished running single baseline postprocessing and power spectrum estimation notebook for ${fn} at $(date) and writing results to ${nb_outfile}.ipynb and ${nb_outfile}.html

    # Check to see that output file was correctly produced
    if [ -f "${fn%.uvh5}.pspec.h5" ]; then
        echo Resulting $f found.
    else
        echo $f not produced.
        exit 1
    fi
else
    echo "File ${full_file_path} is either just autocorrelations or has a fully flagged polarization. Skipping the power spectrum notebook."
fi

# check if ".0_4." is in the filename, if so copy the notebook to the output repo
if [[ "$(basename "$fn")" == *".0_4."* ]]; then
    # Copy file to notebook folder for www access
    dest_dir="${nb_output_repo}/single_baseline_postprocessing_and_pspec"
    mkdir -p "$dest_dir"
    src_html="${nb_outfile%.html}.html"
    cp -v "$src_html" "${dest_dir}/$(basename "${nb_outfile%.html}").html"
fi
