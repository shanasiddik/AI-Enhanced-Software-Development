use anyhow::Result;
use log::info;
use rayon::prelude::*;
use std::fs::File;
use std::io::{BufRead, BufReader};
use crate::config::Config;
use crate::cm::Cm;
use crate::pipeline::Pipeline;
use crate::output::OutputWriter;

pub struct CmSearch {
    config: Config,
    cm: Cm,
    pipeline: Pipeline,
    output_writer: OutputWriter,
}

impl CmSearch {
    pub fn new(config: Config) -> Result<Self> {
        info!("Initializing cmsearch with config: {:?}", config);
        
        // Load CM
        let cm = Cm::from_file(std::path::Path::new(&config.cmfile))?;
        cm.validate()?;
        
        // Initialize pipeline
        let pipeline = Pipeline::new(&cm, &config)?;
        
        // Initialize output writer
        let output_writer = OutputWriter::new(&config)?;
        
        Ok(Self {
            config,
            cm,
            pipeline,
            output_writer,
        })
    }
    
    pub fn run(&mut self) -> Result<()> {
        info!("Starting cmsearch");
        
        // Load sequence database
        let sequences = self.load_sequences()?;
        info!("Loaded {} sequences", sequences.len());
        
        // Run search pipeline
        let hits = self.pipeline.search(&sequences)?;
        info!("Found {} hits", hits.len());
        
        // Write results
        self.output_writer.write_hits(&hits)?;
        
        info!("cmsearch completed successfully");
        Ok(())
    }
    
    fn load_sequences(&self) -> Result<Vec<Sequence>> {
        let file = File::open(&self.config.seqdb)?;
        let reader = BufReader::new(file);
        let mut sequences = Vec::new();
        let mut current_name = String::new();
        let mut current_sequence = String::new();
        
        for line in reader.lines() {
            let line = line?;
            let line = line.trim();
            
            if line.is_empty() {
                continue;
            }
            
            if line.starts_with('>') {
                // Save previous sequence if we have one
                if !current_name.is_empty() {
                    sequences.push(Sequence {
                        name: current_name.clone(),
                        sequence: current_sequence.clone(),
                        length: current_sequence.len(),
                    });
                }
                
                // Start new sequence
                current_name = line[1..].to_string();
                current_sequence.clear();
            } else {
                // Add to current sequence
                current_sequence.push_str(line);
            }
        }
        
        // Don't forget the last sequence
        if !current_name.is_empty() {
            let sequence_length = current_sequence.len();
            sequences.push(Sequence {
                name: current_name,
                sequence: current_sequence,
                length: sequence_length,
            });
        }
        
        info!("Loaded {} sequences from {}", sequences.len(), self.config.seqdb);
        Ok(sequences)
    }
}

#[derive(Debug, Clone)]
pub struct Sequence {
    pub name: String,
    pub sequence: String,
    pub length: usize,
}

#[derive(Debug, Clone)]
pub struct Hit {
    pub sequence_name: String,
    pub start: usize,
    pub end: usize,
    pub score: f64,
    pub evalue: f64,
    pub alignment: Option<String>,
} 