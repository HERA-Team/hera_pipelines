import os
import glob
import re
import argparse
import numpy as np
import toml
from hera_cal import io

# This is the reverse of post-lstbin/corner_turn.py: it gathers the per-baseline sky-model
# files (one cross baseline per file, all LST bins) back into all-baseline files that each
# contain a small number of integrations (INTS_PER_OUTPUT_FILE, default 2), suitable for
# calibrating single data files.
#
# Parallelism: this script is invoked once per obsid (per input single-baseline file). It
# uses this file's index among all input files to pick a round-robin subset of the output
# time-chunks to produce, so that across all obsid jobs every chunk is produced exactly once.

parser = argparse.ArgumentParser()
parser.add_argument("this_file", help="one input single-baseline LST-stack file; used to index into the round-robin over output time-chunks")
parser.add_argument("toml_file", help="path to the build_sky_model toml")
args = parser.parse_args()

# --- read config (lowercase toml keys, matching house style; the notebook uppercases them) ---
config = toml.load(args.toml_file)
MODEL_SUFFIX = config['SKY_MODEL_OPTS']['model_suffix']
OUTDIR = config['SKY_MODEL_OPTS']['outdir']
ct_opts = config['CORNER_TURN_OPTS']
FNAME_FORMAT = ct_opts['fname_format']
INTS_PER_OUTPUT_FILE = int(ct_opts['ints_per_output_file'])

os.makedirs(OUTDIR, exist_ok=True)
model_dir = os.path.join(OUTDIR, 'single_baseline_files')  # where the notebook wrote the models

# --- discover sibling input files (for the round-robin index) and the per-baseline sky models ---
this_file = os.path.abspath(args.this_file)
indir = os.path.dirname(this_file)
basename = os.path.basename(this_file)
match = re.search(r'baseline\.(\d+)_(\d+)', basename)
if match is None:
    raise ValueError(f'Could not parse baseline from {basename}')
ap_str = f'{match.group(1)}_{match.group(2)}'
bl_glob_name = basename.replace(f'baseline.{ap_str}', 'baseline.*')

input_glob = os.path.join(indir, bl_glob_name)
all_input_files = sorted(os.path.abspath(f) for f in glob.glob(input_glob))
model_glob = os.path.join(model_dir, bl_glob_name.replace('.uvh5', MODEL_SUFFIX))
all_model_files = sorted(os.path.abspath(f) for f in glob.glob(model_glob))

if this_file not in all_input_files:
    raise ValueError(f'{this_file} not found in glob {input_glob}')
if len(all_model_files) == 0:
    print(f'No sky-model files ({model_glob}) found; nothing to corner-turn.')
    raise SystemExit(0)

# --- define the output time-chunking from the (shared) LST-bin grid ---
# Chunk into INTS_PER_OUTPUT_FILE consecutive LST bins. If the bin count isn't divisible, the
# trailing remainder (e.g. a lone final integration) is absorbed into the last full chunk rather
# than written as its own short file, so every output file has at least INTS_PER_OUTPUT_FILE bins.
# (All single-baseline files share this LST grid.)
times = np.unique(io.HERAData(all_model_files[0]).times)
n_full = len(times) // INTS_PER_OUTPUT_FILE
chunk_starts = [i * INTS_PER_OUTPUT_FILE for i in range(n_full)]
chunks = [times[s:s + INTS_PER_OUTPUT_FILE] for s in chunk_starts]
remainder = times[n_full * INTS_PER_OUTPUT_FILE:]
if len(remainder) > 0:
    if chunks:
        chunks[-1] = np.concatenate([chunks[-1], remainder])
    else:
        chunks, chunk_starts = [remainder], [0]  # fewer total bins than INTS_PER_OUTPUT_FILE
n_chunks = len(chunks)

# Reference JD for output filenames: start at the lowest JD in the single-baseline files and
# increment by the bin cadence, so files sort monotonically by LST even if the coverage wraps
# through 0/2pi. (match_times reads the true LSTs from each file's metadata, not the filename.)
jd0 = float(times[0])
dt_days = float(np.median(np.diff(times)))

# --- round-robin assignment of chunks to this obsid ---
this_index = all_input_files.index(this_file)
n_jobs = len(all_input_files)
assigned = [(ci, chunk) for ci, chunk in enumerate(chunks) if ci % n_jobs == this_index]
if len(assigned) == 0:
    print(f'No output chunks assigned to index {this_index} of {n_jobs}; nothing to do.')
    raise SystemExit(0)
print(f'This file is index {this_index} of {n_jobs}; producing {len(assigned)} of {n_chunks} output chunk(s).')

# --- read every sky-model file once, restricted to the union of this job's assigned times ---
union_times = np.unique(np.concatenate([chunk for _, chunk in assigned]))
print(f'Reading {len(all_model_files)} sky-model files at {len(union_times)} times...')
hd = io.HERAData(all_model_files)
hd.read(times=union_times, axis='blt')

add_to_history = '\nProduced from per-baseline sky-model files with corner_return_2int.py.'

# --- write one all-baseline file per assigned chunk ---
for ci, chunk in assigned:
    hd_chunk = hd.select(inplace=False, times=chunk)
    file_jd = jd0 + chunk_starts[ci] * dt_days  # monotonic reference JD for the filename
    outfile = os.path.join(OUTDIR, FNAME_FORMAT.format(jd=file_jd, chunk=ci))
    hd_chunk.history += add_to_history
    print(f'\tWriting chunk {ci} ({len(chunk)} integrations) to {outfile}')
    hd_chunk.write_uvh5(outfile, clobber=True)

print(f'Finished corner-returning {len(assigned)} chunk(s).')
