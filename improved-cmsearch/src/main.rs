use clap::{Parser, Subcommand};
use log::{info, error, warn};
use anyhow::{Result, Context};
use rayon::ThreadPoolBuilder;

mod cm;
mod pipeline;
mod search;
mod utils;
mod config;
mod worker;
mod output;

use crate::config::Config;
use crate::search::CmSearch;

#[derive(Parser)]
#[command(name = "improved-cmsearch")]
#[command(about = "Improved cmsearch implementation in Rust")]
#[command(version = "0.1.0")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    
    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,
    
    /// Number of threads to use
    #[arg(short, long, default_value = "1")]
    threads: usize,
}

#[derive(Subcommand)]
enum Commands {
    /// Search CM(s) against a sequence database
    Search {
        /// CM file path
        #[arg(required = true)]
        cmfile: String,
        
        /// Sequence database file path
        #[arg(required = true)]
        seqdb: String,
        
        /// Output file (default: stdout)
        #[arg(short, long)]
        output: Option<String>,
        
        /// E-value threshold
        #[arg(short = 'E', long, default_value = "10.0")]
        evalue: f64,
        
        /// Score threshold
        #[arg(short = 'T', long)]
        score: Option<f64>,
        
        /// Include alignments in output
        #[arg(short = 'A', long)]
        alignments: bool,
        
        /// Tabular output format
        #[arg(short = 't', long)]
        tabular: bool,
        
        /// Use HMM filter
        #[arg(long)]
        hmm_filter: bool,
        
        /// Maximum matrix size in MB
        #[arg(long, default_value = "1024")]
        max_mx_size: f64,
        
        /// Enable truncated alignments
        #[arg(long)]
        trunc: bool,
        
        /// Number of passes
        #[arg(long, default_value = "3")]
        passes: usize,
    },
    
    /// Validate CM file
    Validate {
        /// CM file path
        #[arg(required = true)]
        cmfile: String,
    },
    
    /// Show CM information
    Info {
        /// CM file path
        #[arg(required = true)]
        cmfile: String,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    
    // Configure rayon thread pool
    ThreadPoolBuilder::new()
        .num_threads(cli.threads)
        .build_global()
        .expect("Failed to configure thread pool");
    
    // Initialize logging
    if cli.verbose {
        std::env::set_var("RUST_LOG", "debug");
    } else {
        std::env::set_var("RUST_LOG", "info");
    }
    env_logger::init();
    
    info!("Starting improved-cmsearch v0.1.0");
    
    match cli.command {
        Commands::Search { 
            cmfile, 
            seqdb, 
            output, 
            evalue, 
            score, 
            alignments, 
            tabular, 
            hmm_filter, 
            max_mx_size, 
            trunc, 
            passes 
        } => {
            let config = Config {
                cmfile,
                seqdb,
                output,
                evalue,
                score,
                alignments,
                tabular,
                hmm_filter,
                max_mx_size,
                trunc,
                passes,
                threads: cli.threads,
            };
            
            let mut searcher = CmSearch::new(config)?;
            searcher.run()?;
        }
        
        Commands::Validate { cmfile } => {
            info!("Validating CM file: {}", cmfile);
            let cm = cm::Cm::from_file(std::path::Path::new(&cmfile))?;
            info!("CM validation successful");
            info!("Model name: {}", cm.name);
            info!("Model length: {}", cm.length);
            info!("Alphabet: {:?}", cm.alphabet);
        }
        
        Commands::Info { cmfile } => {
            info!("Showing CM information: {}", cmfile);
            let cm = cm::Cm::from_file(std::path::Path::new(&cmfile))?;
            println!("CM Information:");
            println!("  Name: {}", cm.name);
            println!("  Length: {}", cm.length);
            println!("  Alphabet: {:?}", cm.alphabet);
            println!("  Nodes: {}", cm.nodes.len());
            println!("  States: {}", cm.states.len());
        }
    }
    
    info!("Completed successfully");
    Ok(())
} 