#!/bin/sh
# Script for backing up H4C data products.

# Backup all lstbinned data.
rsync -r /lustre/aoc/projects/hera/H4C/posprocessing/lstbin herastore01:/export/hera/herastore01-2/H4C/
