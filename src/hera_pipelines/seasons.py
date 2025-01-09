"""A module defining defaults for different HERA seasons."""
from pathlib import Path

H6C = {
    'root_stage': Path('/lustre/aoc/projects/hera/H6C'),
    'analysis_dir': Path('/lustre/aoc/projects/hera/h6c-analysis'),
    'validation_dir': Path("/lustre/aoc/projects/hera/Validation/H6C_IDR2")
}


seasons = {
    'h6c': H6C,
    'h10c': H6C
}
