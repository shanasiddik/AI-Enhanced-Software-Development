#!/usr/bin/env python3
"""
Script to create metagenomes by combining reads from individual genomes
with different abundance ratios and replicates.
"""

import os
import random
import shutil
from pathlib import Path
import argparse

def get_read_files(organism_dirs):
    """Get all read files from organism directories"""
    read_files = {}
    
    for org_dir in organism_dirs:
        org_path = Path(org_dir)
        if org_path.exists():
            # Find the read file (non-FastQC files)
            read_files_found = [f for f in org_path.iterdir() 
                              if f.is_file() and not f.name.endswith(('_fastqc.html', '_fastqc.zip'))]
            
            if read_files_found:
                read_files[org_dir] = read_files_found[0]  # Take the first (and likely only) read file
                print(f"Found reads for {org_dir}: {read_files_found[0].name}")
            else:
                print(f"No read files found in {org_dir}")
        else:
            print(f"Directory {org_dir} does not exist")
    
    return read_files

def count_reads_in_file(file_path):
    """Count number of reads in a FASTQ file"""
    with open(file_path, 'r') as f:
        return sum(1 for line in f) // 4

def sample_reads(input_file, output_file, num_reads, seed=None):
    """Sample a specific number of reads from a FASTQ file"""
    if seed is not None:
        random.seed(seed)
    
    total_reads = count_reads_in_file(input_file)
    
    if num_reads >= total_reads:
        # If we want all reads, just copy the file
        shutil.copy2(input_file, output_file)
        return total_reads
    
    # Sample random line numbers (every 4th line starting from 0, 1, 2, 3)
    selected_lines = set()
    while len(selected_lines) < num_reads:
        read_start = random.randint(0, total_reads - 1) * 4
        for i in range(4):  # Each read is 4 lines
            selected_lines.add(read_start + i)
    
    # Write selected reads to output file
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line_num, line in enumerate(infile):
            if line_num in selected_lines:
                outfile.write(line)
    
    return len(selected_lines) // 4

def create_metagenome(euk_files, phage_files, euk_ratio, phage_ratio, output_dir, replicate_num, total_reads=100000):
    """Create a metagenome with specified ratios"""
    
    # Calculate number of reads for each group
    euk_reads = int(total_reads * euk_ratio)
    phage_reads = int(total_reads * phage_ratio)
    
    # Calculate reads per organism
    reads_per_euk = euk_reads // len(euk_files) if euk_files else 0
    reads_per_phage = phage_reads // len(phage_files) if phage_files else 0
    
    print(f"\nCreating metagenome replicate {replicate_num}:")
    print(f"  Eukaryotes: {euk_reads} reads ({euk_ratio*100:.1f}%)")
    print(f"  Phages: {phage_reads} reads ({phage_ratio*100:.1f}%)")
    print(f"  Reads per eukaryote: {reads_per_euk}")
    print(f"  Reads per phage: {reads_per_phage}")
    
    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Output file
    output_file = output_path / f"metagenome_euk{euk_ratio*100:.0f}_phage{phage_ratio*100:.0f}_rep{replicate_num}.fastq"
    
    # Combine reads
    with open(output_file, 'w') as outfile:
        # Add eukaryote reads
        for org_name, read_file in euk_files.items():
            if reads_per_euk > 0:
                print(f"  Adding {reads_per_euk} reads from {org_name}")
                temp_file = output_path / f"temp_{org_name}_rep{replicate_num}.fastq"
                actual_reads = sample_reads(read_file, temp_file, reads_per_euk, seed=replicate_num)
                
                with open(temp_file, 'r') as temp:
                    outfile.write(temp.read())
                
                # Clean up temp file
                temp_file.unlink()
                print(f"    Actually added {actual_reads} reads")
        
        # Add phage reads
        for org_name, read_file in phage_files.items():
            if reads_per_phage > 0:
                print(f"  Adding {reads_per_phage} reads from {org_name}")
                temp_file = output_path / f"temp_{org_name}_rep{replicate_num}.fastq"
                actual_reads = sample_reads(read_file, temp_file, reads_per_phage, seed=replicate_num)
                
                with open(temp_file, 'r') as temp:
                    outfile.write(temp.read())
                
                # Clean up temp file
                temp_file.unlink()
                print(f"    Actually added {actual_reads} reads")
    
    # Count final reads
    final_read_count = count_reads_in_file(output_file)
    print(f"  Final metagenome: {final_read_count} reads")
    
    return output_file, final_read_count

def main():
    parser = argparse.ArgumentParser(description='Create metagenomes from individual genome reads')
    parser.add_argument('--base-dir', default='.', help='Base directory containing organism folders')
    parser.add_argument('--output-dir', default='metagenomes', help='Output directory for metagenomes')
    parser.add_argument('--total-reads', type=int, default=100000, help='Total reads per metagenome')
    parser.add_argument('--replicates', type=int, default=3, help='Number of replicates per ratio')
    
    args = parser.parse_args()
    
    base_dir = Path(args.base_dir)
    output_dir = Path(args.output_dir)
    
    # Define organism directories
    euk_dirs = ['euk1', 'euk2', 'euk3']
    phage_dirs = ['phage1', 'phage2', 'phage3', 'phage4', 'phage5']
    
    # Get read files
    print("Finding read files...")
    euk_files = get_read_files([base_dir / d for d in euk_dirs])
    phage_files = get_read_files([base_dir / d for d in phage_dirs])
    
    print(f"\nFound {len(euk_files)} eukaryote files and {len(phage_files)} phage files")
    
    # Define abundance ratios (eukaryotes, phages)
    ratios = [
        (0.7, 0.3),  # 70% eukaryotes, 30% phages
        (0.5, 0.5),  # 50% eukaryotes, 50% phages
        (0.3, 0.7),  # 30% eukaryotes, 70% phages
    ]
    
    # Create metagenomes
    results = []
    for euk_ratio, phage_ratio in ratios:
        for rep in range(1, args.replicates + 1):
            output_file, read_count = create_metagenome(
                euk_files, phage_files, euk_ratio, phage_ratio, 
                output_dir, rep, args.total_reads
            )
            results.append({
                'file': output_file,
                'euk_ratio': euk_ratio,
                'phage_ratio': phage_ratio,
                'replicate': rep,
                'reads': read_count
            })
    
    # Print summary
    print(f"\n{'='*60}")
    print("METAGENOME CREATION SUMMARY")
    print(f"{'='*60}")
    print(f"Output directory: {output_dir}")
    print(f"Total metagenomes created: {len(results)}")
    print(f"\nFiles created:")
    
    for result in results:
        print(f"  {result['file'].name}")
        print(f"    Ratio: {result['euk_ratio']*100:.0f}% eukaryotes, {result['phage_ratio']*100:.0f}% phages")
        print(f"    Replicate: {result['replicate']}")
        print(f"    Reads: {result['reads']:,}")
        print()
    
    # Create a summary file
    summary_file = output_dir / "metagenome_summary.txt"
    with open(summary_file, 'w') as f:
        f.write("Metagenome Creation Summary\n")
        f.write("=" * 40 + "\n\n")
        f.write(f"Total metagenomes: {len(results)}\n")
        f.write(f"Total reads per metagenome: {args.total_reads:,}\n")
        f.write(f"Replicates per ratio: {args.replicates}\n\n")
        
        f.write("Files created:\n")
        f.write("-" * 20 + "\n")
        for result in results:
            f.write(f"{result['file'].name}\n")
            f.write(f"  Ratio: {result['euk_ratio']*100:.0f}% eukaryotes, {result['phage_ratio']*100:.0f}% phages\n")
            f.write(f"  Replicate: {result['replicate']}\n")
            f.write(f"  Reads: {result['reads']:,}\n\n")
    
    print(f"Summary saved to: {summary_file}")

if __name__ == "__main__":
    main()
