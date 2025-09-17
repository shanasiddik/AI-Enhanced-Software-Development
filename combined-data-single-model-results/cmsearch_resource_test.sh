#!/bin/bash

# cmsearch_resource_test.sh
# Run cmsearch with various thread counts, measure resource usage, and compare hit counts to reference.
# Usage: ./cmsearch_resource_test.sh <output_dir>

THREADS=(1 2 4 8 16 32)
SUMMARY="cmsearch_summary_results.tsv"
CMSEARCH_DIR="/clusterfs/jgi/scratch/science/mgs/nelli/shana/infernal-1.1.5"

# Fixed paths
CM_FILE="/clusterfs/jgi/scratch/science/mgs/nelli/shana/ssuextract/resources/models/RF00177.cm"
FASTA_FILE="/clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-software-development/dataset/combined/combined_dataset.fasta"
REFERENCE_FILE="reference_cmsearch_output.txt"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <output_dir>"
  echo "Example: $0 results/cmsearch_test"
  exit 1
fi

OUTPUT_DIR="$1"

# Check if required files exist
if [ ! -f "$CM_FILE" ]; then
  echo "Error: CM model file not found: $CM_FILE"
  exit 1
fi

if [ ! -f "$FASTA_FILE" ]; then
  echo "Error: FASTA file not found: $FASTA_FILE"
  exit 1
fi

if [ ! -f "$REFERENCE_FILE" ]; then
  echo "Error: Reference file not found: $REFERENCE_FILE"
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Count reference hits
REFERENCE_HITS=$(grep -c "^  ([0-9]*)" "$REFERENCE_FILE" || echo "0")
echo "Reference hit count: $REFERENCE_HITS"

# Write header for summary
printf "Threads\tPeakMemory(MB)\tCPU(%%)\tWallTime(s)\tNumHits\tMatch\n" > "$SUMMARY"

for T in "${THREADS[@]}"; do
  OUTDIR="run_t${T}"
  mkdir -p "$OUTDIR"

  TIMEFILE="${OUTDIR}/time.txt"
  LOGFILE="${OUTDIR}/cmsearch.log"
  OUTPUT_FILE="${OUTDIR}/cmsearch_output.txt"

  # Save current directory
  CURDIR="$(pwd)"

  echo "Running: cmsearch --cpu $T $CM_FILE $FASTA_FILE (from $CMSEARCH_DIR)"
  cd "$CMSEARCH_DIR"
  /usr/bin/time -v -o "$CURDIR/$TIMEFILE" ./src/cmsearch --cpu "$T" "$CM_FILE" "$FASTA_FILE" > "$CURDIR/$OUTPUT_FILE" 2>"$CURDIR/$LOGFILE"
  cd "$CURDIR"

  # Copy the output file to the specified output directory
  if [ -f "$OUTPUT_FILE" ]; then
    cp "$OUTPUT_FILE" "$OUTPUT_DIR/cmsearch_output_t${T}.txt"
  fi

  # Extract resource usage
  PEAK_MEM=$(grep "Maximum resident set size" "$TIMEFILE" | awk '{print $6/1024}')
  CPU_PERC=$(grep "Percent of CPU this job got" "$TIMEFILE" | awk '{print $NF}' | sed 's/%//')
  WALL_TIME=$(grep "Elapsed (wall clock) time" "$TIMEFILE" | awk '{print $8}')

  # Count number of hits and compare to reference
  if [ -f "$OUTPUT_FILE" ]; then
    NUM_HITS=$(grep -c "^  ([0-9]*)" "$OUTPUT_FILE" || echo "0")
    if [ "$NUM_HITS" -eq "$REFERENCE_HITS" ]; then
      MATCH="Yes"
    else
      MATCH="No"
    fi
  else
    NUM_HITS="0"
    MATCH="No"
  fi

  printf "%d\t%.2f\t%s\t%s\t%d\t%s\n" "$T" "$PEAK_MEM" "$CPU_PERC" "$WALL_TIME" "$NUM_HITS" "$MATCH" >> "$SUMMARY"
done

echo "Test complete. See $SUMMARY for results." 