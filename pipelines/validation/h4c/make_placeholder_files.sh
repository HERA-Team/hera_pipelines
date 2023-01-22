
data_dir=$1
outdir=$2

data_files=$(ls $data_dir/*.sum.autos.uvh5)
for file in $data_files; do
    fn=$(basename $file)
    touch ${outdir}/${fn%.sum.autos.uvh5}.xx.HH.uv
done
