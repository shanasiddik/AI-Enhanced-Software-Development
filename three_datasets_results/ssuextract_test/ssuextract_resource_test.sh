#!/bin/bash

# ssuextract_resource_test.sh
# Run ssuextract pipeline with various thread counts, measure resource usage, and compare output to expected.
# Usage: ./cmsearch_resource_test.sh <reference_summary_file> <pipeline_querydir> <pipeline_summary_path>

THREADS=(1 2 4 8 16 32)
SUMMARY="summary_results.tsv"
BASE_OUTDIR="AI-software-development"
PIXIDIR="/clusterfs/jgi/scratch/science/mgs/nelli/shana/ssuextract"

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <reference_summary_file> <pipeline_querydir> <pipeline_summary_path>"
  echo "Example: $0 /path/to/ref/cmsearch_summary.tsv data/my_dataset results/my_dataset/cmsearch_summary.tsv"
  exit 1
fi

REFERENCE="$1"
QUERYDIR="$2"
SUMMARY_PATH="$3"

# Write header for summary
printf "Threads\tPeakMemory(MB)\tCPU(%%)\tWallTime(s)\tOutputMatch\n" > "$SUMMARY"

for T in "${THREADS[@]}"; do
  OUTDIR="${BASE_OUTDIR}/run_t${T}"
  mkdir -p "$OUTDIR"

  TIMEFILE="${OUTDIR}/time.txt"
  LOGFILE="${OUTDIR}/pipeline.log"

  # Save current directory
  CURDIR="$(pwd)"

  echo "Running: pixi run nextflow run main.nf --querydir $QUERYDIR --threads_per_job $T (from $PIXIDIR)"
  cd "$PIXIDIR"
  /usr/bin/time -v -o "$CURDIR/$TIMEFILE" pixi run nextflow run main.nf --querydir "$QUERYDIR" --threads_per_job "$T" > "$CURDIR/$LOGFILE" 2>&1
  cd "$CURDIR"

  # Copy the summary file to the run directory
  if [ -f "$SUMMARY_PATH" ]; then
    cp "$SUMMARY_PATH" "$OUTDIR/cmsearch_summary.tsv"
  fi

  # Extract resource usage
  PEAK_MEM=$(grep "Maximum resident set size" "$TIMEFILE" | awk '{print $6/1024}')
  CPU_PERC=$(grep "Percent of CPU this job got" "$TIMEFILE" | awk '{print $8}')
  WALL_TIME=$(grep "Elapsed (wall clock) time" "$TIMEFILE" | awk '{print $8}')

  # Compare output
  if [ -f "$OUTDIR/cmsearch_summary.tsv" ]; then
    if diff -q "$OUTDIR/cmsearch_summary.tsv" "$REFERENCE" > /dev/null; then
      MATCH="Yes"
    else
      MATCH="No"
    fi
  else
    MATCH="NoFile"
  fi

  printf "%d\t%.2f\t%s\t%s\t%s\n" "$T" "$PEAK_MEM" "$CPU_PERC" "$WALL_TIME" "$MATCH" >> "$SUMMARY"
done

echo "Test complete. See $SUMMARY for results." 