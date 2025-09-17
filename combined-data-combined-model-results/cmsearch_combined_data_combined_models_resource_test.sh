#!/bin/bash

# cmsearch_combined_data_combined_models_resource_test.sh
# Run cmsearch across all models in the specified models dir against the combined dataset,
# measure resource usage, and aggregate results into a summary TSV.
# Usage: ./cmsearch_combined_data_combined_models_resource_test.sh <output_dir>

THREADS=(1 2 4 8 16 32)
SUMMARY="cmsearch_combined_models_summary.tsv"
CMSEARCH_DIR="/clusterfs/jgi/scratch/science/mgs/nelli/shana/infernal-1.1.5"

# Fixed paths
MODELS_DIR="/clusterfs/jgi/scratch/science/mgs/nelli/shana/ssuextract/resources/models"
COMBINED_FASTA="/clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-Enhanced-Software-Development/dataset/combined/combined_dataset.fasta"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <output_dir>"
  echo "Example: $0 combined-data-combined-model-results/run_$(date +%Y%m%d_%H%M%S)"
  exit 1
fi

OUTPUT_DIR="$1"

# Validate inputs
if [ ! -d "$MODELS_DIR" ]; then
  echo "Error: Models directory not found: $MODELS_DIR"
  exit 1
fi

if [ ! -f "$COMBINED_FASTA" ]; then
  echo "Error: Combined FASTA file not found: $COMBINED_FASTA"
  exit 1
fi

# Collect model files
mapfile -t MODEL_FILES < <(find "$MODELS_DIR" -maxdepth 1 -type f -name "*.cm" | sort)
if [ "${#MODEL_FILES[@]}" -eq 0 ]; then
  echo "Error: No .cm model files found in $MODELS_DIR"
  exit 1
fi

# Prepare output directory
mkdir -p "$OUTPUT_DIR"

# Write header for combined summary
# Columns: Model\tThreads\tPeakMemory(MB)\tCPU(%)\tWallTime(s)\tNumHits
printf "Model\tThreads\tPeakMemory(MB)\tCPU(%%)\tWallTime(s)\tNumHits\n" > "$OUTPUT_DIR/$SUMMARY"

for CM_FILE in "${MODEL_FILES[@]}"; do
  MODEL_NAME=$(basename "$CM_FILE")
  MODEL_STEM="${MODEL_NAME%.cm}"
  MODEL_OUTDIR="$OUTPUT_DIR/$MODEL_STEM"
  mkdir -p "$MODEL_OUTDIR"

  for T in "${THREADS[@]}"; do
    RUN_OUTDIR="$MODEL_OUTDIR/run_t${T}"
    mkdir -p "$RUN_OUTDIR"

    TIMEFILE="$RUN_OUTDIR/time.txt"
    LOGFILE="$RUN_OUTDIR/cmsearch.log"
    OUTPUT_FILE="$RUN_OUTDIR/cmsearch_output.txt"

    # Save current directory
    CURDIR="$(pwd)"

    echo "Running: cmsearch --cpu $T $CM_FILE $COMBINED_FASTA (from $CMSEARCH_DIR)"
    cd "$CMSEARCH_DIR"
    /usr/bin/time -v -o "$TIMEFILE" ./src/cmsearch --cpu "$T" "$CM_FILE" "$COMBINED_FASTA" > "$OUTPUT_FILE" 2>"$LOGFILE"
    cd "$CURDIR"

    # Extract resource usage
    PEAK_MEM=$(grep "Maximum resident set size" "$TIMEFILE" | awk '{print $6/1024}')
    CPU_PERC=$(grep "Percent of CPU this job got" "$TIMEFILE" | awk '{print $NF}' | sed 's/%//')
    WALL_TIME=$(grep "Elapsed (wall clock) time" "$TIMEFILE" | awk '{print $8}')

    # Count number of hits
    if [ -f "$OUTPUT_FILE" ]; then
      NUM_HITS=$(grep -c "^  ([0-9]*)" "$OUTPUT_FILE" || echo "0")
    else
      NUM_HITS="0"
    fi

    printf "%s\t%d\t%.2f\t%s\t%s\t%d\n" "$MODEL_NAME" "$T" "$PEAK_MEM" "$CPU_PERC" "$WALL_TIME" "$NUM_HITS" >> "$OUTPUT_DIR/$SUMMARY"
  done

done

echo "Complete. See $OUTPUT_DIR/$SUMMARY for aggregated results and per-run outputs under $OUTPUT_DIR/<model>/run_t*/."
