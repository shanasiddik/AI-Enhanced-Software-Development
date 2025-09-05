#!/bin/bash

# Performance testing script for improved-cmsearch Rust implementation
# Records CPU% and WallTime(s) for different thread counts
# Usage: ./performance_test_script.sh <model.cm> <sequences_dir> [output_dir]
#        ./performance_test_script.sh <model.cm> "file1.fasta file2.fasta file3.fasta" [output_dir]

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <model.cm> <sequences_dir_or_files> [output_dir]"
    echo "Example: $0 model.cm sequences/ results/"
    echo "Example: $0 model.cm \"file1.fasta file2.fasta file3.fasta\" results/"
    exit 1
fi

MODEL_CM="$1"
SEQUENCES_INPUT="$2"
OUTPUT_DIR="${3:-performance_results}"

# Thread counts to test
THREADS=(1 2 4 8 16 32)

# Binary path
BINARY="/clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-Enhanced-Software-Development/improved-cmsearch/target/release/improved-cmsearch"

# Reference file path
REFERENCE_FILE="/clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-Enhanced-Software-Development/three_datasets_results/cmsearch_test/reference_cmsearch_output.txt"

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    echo "Please build the project first: cargo build --release"
    exit 1
fi

# Check if input files exist
if [ ! -f "$MODEL_CM" ]; then
    echo "Error: Model file not found: $MODEL_CM"
    exit 1
fi

if [ ! -f "$SEQUENCES_INPUT" ]; then
    echo "Error: Sequences file not found: $SEQUENCES_INPUT"
    exit 1
fi

if [ ! -f "$REFERENCE_FILE" ]; then
    echo "Error: Reference file not found: $REFERENCE_FILE"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Results file
RESULTS_FILE="$OUTPUT_DIR/performance_results.tsv"

# Count reference hits
REFERENCE_HITS=$(grep -c "^  ([0-9]*)" "$REFERENCE_FILE" || echo "0")
echo "Reference hit count: $REFERENCE_HITS"

# Write header
printf "Threads\tPeakMemory(MB)\tCPU(%%)\tWallTime(s)\tNumHits\tMatch\n" > "$RESULTS_FILE"

echo "Starting performance tests..."
echo "Model: $MODEL_CM"
echo "Sequences: $SEQUENCES_INPUT"
echo "Output directory: $OUTPUT_DIR"
echo "Results file: $RESULTS_FILE"
echo ""

for T in "${THREADS[@]}"; do
    echo "Testing with $T thread(s)..."
    
    # Create thread-specific output directory
    THREAD_OUTDIR="$OUTPUT_DIR/run_t${T}"
    mkdir -p "$THREAD_OUTDIR"
    
    # Output files
    TIMEFILE="$THREAD_OUTDIR/time.txt"
    LOGFILE="$THREAD_OUTDIR/cmsearch.log"
    OUTPUT_FILE="$THREAD_OUTDIR/results.txt"
    
    # Save current directory
    CURDIR="$(pwd)"
    
    # Run cmsearch with time measurement
    echo "Running: $BINARY --threads $T search $MODEL_CM $SEQUENCES_INPUT -o $OUTPUT_FILE"
    
    /usr/bin/time -v -o "$TIMEFILE" \
        "$BINARY" --threads "$T" search "$MODEL_CM" "$SEQUENCES_INPUT" \
        -o "$OUTPUT_FILE" \
        -E 1.0 \
        -T 0.1 \
        > "$LOGFILE" 2>&1
    
    # Extract resource usage from time output
    if [ -f "$TIMEFILE" ]; then
        PEAK_MEM=$(grep "Maximum resident set size" "$TIMEFILE" | awk '{print $6/1024}')
        CPU_PERC=$(grep "Percent of CPU this job got" "$TIMEFILE" | awk '{print $NF}' | sed 's/%//')
        WALL_TIME=$(grep "Elapsed (wall clock) time" "$TIMEFILE" | awk '{print $8}')
        
        # Convert wall time to seconds
        if [[ "$WALL_TIME" =~ ^([0-9]+):([0-9]+)\.([0-9]+)$ ]]; then
            MINUTES="${BASH_REMATCH[1]}"
            SECONDS="${BASH_REMATCH[2]}"
            HUNDREDTHS="${BASH_REMATCH[3]}"
            WALL_TIME_SEC=$(echo "$MINUTES * 60 + $SECONDS + $HUNDREDTHS / 100" | bc -l)
        elif [[ "$WALL_TIME" =~ ^([0-9]+):([0-9]+):([0-9]+)\.([0-9]+)$ ]]; then
            HOURS="${BASH_REMATCH[1]}"
            MINUTES="${BASH_REMATCH[2]}"
            SECONDS="${BASH_REMATCH[3]}"
            HUNDREDTHS="${BASH_REMATCH[4]}"
            WALL_TIME_SEC=$(echo "$HOURS * 3600 + $MINUTES * 60 + $SECONDS + $HUNDREDTHS / 100" | bc -l)
        else
            WALL_TIME_SEC="$WALL_TIME"
        fi
        
        # Count number of hits from output file and compare to reference
        if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
            # Extract hit count from Rust output format "Hits: X"
            NUM_HITS=$(grep "Hits:" "$OUTPUT_FILE" | awk '{print $2}' || echo "0")
            if [ "$NUM_HITS" -eq "$REFERENCE_HITS" ]; then
                MATCH="Yes"
            else
                MATCH="No"
            fi
        else
            NUM_HITS="0"
            MATCH="No"
        fi
        
        printf "%d\t%.2f\t%s\t%.2f\t%d\t%s\n" "$T" "$PEAK_MEM" "$CPU_PERC" "$WALL_TIME_SEC" "$NUM_HITS" "$MATCH" >> "$RESULTS_FILE"
        
        echo "  Threads: $T, Memory: ${PEAK_MEM}MB, CPU: ${CPU_PERC}%, Time: ${WALL_TIME_SEC}s, Hits: $NUM_HITS, Match: $MATCH"
    else
        echo "  Error: Time file not generated for $T threads"
        printf "%d\t0.00\t0\t0.00\t0\tNo\n" "$T" >> "$RESULTS_FILE"
    fi
    
    echo ""
done

echo "Performance testing complete!"
echo "Results saved to: $RESULTS_FILE"
echo ""
echo "Summary of results:"
echo "=================="
cat "$RESULTS_FILE" 