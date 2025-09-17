#!/bin/bash

# cmsearch_three_datasets_resource_test.sh
# Run cmsearch for one model across three datasets, measure resource usage, and aggregate results.
# Usage: ./cmsearch_three_datasets_resource_test.sh <output_dir>

THREADS=(1 2 4 8 16 32)
SUMMARY="cmsearch_three_datasets_summary.tsv"
CMSEARCH_DIR="/clusterfs/jgi/scratch/science/mgs/nelli/shana/infernal-1.1.5"

# Fixed paths
CM_FILE="/clusterfs/jgi/scratch/science/mgs/nelli/shana/ssuextract/resources/models/RF00177.cm"
DATASETS=(
  "/clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-Enhanced-Software-Development/dataset/contigs_drinking_water_microbiome_spike_in_GCF_000008485__depth10.fasta"
  "/clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-Enhanced-Software-Development/dataset/contigs_drinking_water_microbiome_spike_in_GCF_000621645__depth10.fasta"
  "/clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-Enhanced-Software-Development/dataset/contigs_drinking_water_microbiome_spike_in_GCF_001457615__depth10.fasta"
)

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <output_dir>"
  echo "Example: $0 separate-data-single-model-results/run_$(date +%Y%m%d_%H%M%S)"
  exit 1
fi

OUTPUT_DIR="$1"

# Validate required files
if [ ! -f "$CM_FILE" ]; then
  echo "Error: CM model file not found: $CM_FILE"
  exit 1
fi

for FASTA_FILE in "${DATASETS[@]}"; do
  if [ ! -f "$FASTA_FILE" ]; then
    echo "Error: FASTA file not found: $FASTA_FILE"
    exit 1
  fi
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Write header for combined summary
# Columns: Dataset	Threads	PeakMemory(MB)	CPU(%)	WallTime(s)	NumHits
printf "Dataset\tThreads\tPeakMemory(MB)\tCPU(%%)\tWallTime(s)\tNumHits\n" > "$OUTPUT_DIR/$SUMMARY"

for FASTA_FILE in "${DATASETS[@]}"; do
  DATASET_NAME=$(basename "$FASTA_FILE")
  DATASET_STEM="${DATASET_NAME%.fasta}"
  DATASET_OUTDIR="$OUTPUT_DIR/$DATASET_STEM"
  mkdir -p "$DATASET_OUTDIR"

  for T in "${THREADS[@]}"; do
    RUN_OUTDIR="$DATASET_OUTDIR/run_t${T}"
    mkdir -p "$RUN_OUTDIR"

    TIMEFILE="$RUN_OUTDIR/time.txt"
    LOGFILE="$RUN_OUTDIR/cmsearch.log"
    OUTPUT_FILE="$RUN_OUTDIR/cmsearch_output.txt"

    # Save current directory
    CURDIR="$(pwd)"

    echo "Running: cmsearch --cpu $T $CM_FILE $FASTA_FILE (from $CMSEARCH_DIR)"
    cd "$CMSEARCH_DIR"
    /usr/bin/time -v -o "$TIMEFILE" ./src/cmsearch --cpu "$T" "$CM_FILE" "$FASTA_FILE" > "$OUTPUT_FILE" 2>"$LOGFILE"
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

    printf "%s\t%d\t%.2f\t%s\t%s\t%d\n" "$DATASET_NAME" "$T" "$PEAK_MEM" "$CPU_PERC" "$WALL_TIME" "$NUM_HITS" >> "$OUTPUT_DIR/$SUMMARY"
  done

done

echo "Complete. See $OUTPUT_DIR/$SUMMARY for aggregated results and per-run outputs under $OUTPUT_DIR/<dataset>/run_t*/."
