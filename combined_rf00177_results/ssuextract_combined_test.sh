#!/bin/bash

# combined_rf00177_test.sh
# Run ssuextract pipeline with various thread counts on combined dataset, 
# measure resource usage, and compare output to expected (RF00177 only).
# Usage: ./combined_rf00177_test.sh
# Run ssuextract pipeline with various thread counts on combined dataset, 
# measure resource usage, and compare output to expected (RF00177 only).

THREADS=(1 2 4 8 16 32)
SUMMARY="summary_results_combined_rf00177.tsv"
BASE_OUTDIR="combined_rf00177_results"
PIXIDIR="/clusterfs/jgi/scratch/science/mgs/nelli/shana/ssuextract"

REFERENCE="/clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-software-development/ssuextract_results/my_dataset/cmsearch_summary_combined_rf00177.tsv"
QUERYDIR="/clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-software-development/dataset/combined/"
SUMMARY_PATH="/clusterfs/jgi/scratch/science/mgs/nelli/shana/ssuextract/results/combined/cmsearch_summary.tsv"

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

  # Copy the summary file from its output location to the run directory for comparison
  if [ -f "$SUMMARY_PATH" ]; then
    cp "$SUMMARY_PATH" "$OUTDIR/cmsearch_summary.tsv"
    
    # Filter for RF00177 only and save to a separate file for comparison
    if [ -f "$OUTDIR/cmsearch_summary.tsv" ]; then
      # Create header and filter for RF00177
      head -n 1 "$OUTDIR/cmsearch_summary.tsv" > "$OUTDIR/cmsearch_summary_rf00177.tsv"
      awk -F'\t' '$3 == "RF00177"' "$OUTDIR/cmsearch_summary.tsv" >> "$OUTDIR/cmsearch_summary_rf00177.tsv"
    fi
  fi

  # Compare output (using the filtered RF00177 file)
  if [ -f "$OUTDIR/cmsearch_summary_rf00177.tsv" ]; then
    if diff -q "$OUTDIR/cmsearch_summary_rf00177.tsv" "$REFERENCE" > /dev/null; then
      MATCH="Yes"
    else
      MATCH="No"
    fi
  else
    MATCH="NoFile"
  fi

  # Extract resource usage
  PEAK_MEM=$(grep "Maximum resident set size" "$TIMEFILE" | awk '{print $6/1024}')
  CPU_PERC=$(grep "Percent of CPU this job got" "$TIMEFILE" | awk '{print $7}' | sed 's/%//')
  WALL_TIME=$(grep "Elapsed (wall clock) time" "$TIMEFILE" | awk '{print $8}')
  
  # Handle cases where values might be missing
  if [ -z "$PEAK_MEM" ]; then PEAK_MEM="0"; fi
  if [ -z "$CPU_PERC" ]; then CPU_PERC="0"; fi
  if [ -z "$WALL_TIME" ]; then WALL_TIME="0:00.00"; fi

  printf "%d\t%.2f\t%s\t%s\t%s\n" "$T" "$PEAK_MEM" "$CPU_PERC" "$WALL_TIME" "$MATCH" >> "$SUMMARY"
done

echo "Test complete. See $SUMMARY for results." 