use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub cmfile: String,
    pub seqdb: String,
    pub output: Option<String>,
    pub evalue: f64,
    pub score: Option<f64>,
    pub alignments: bool,
    pub tabular: bool,
    pub hmm_filter: bool,
    pub max_mx_size: f64,
    pub trunc: bool,
    pub passes: usize,
    pub threads: usize,
}

impl Config {
    pub fn new() -> Self {
        Self {
            cmfile: String::new(),
            seqdb: String::new(),
            output: None,
            evalue: 10.0,
            score: None,
            alignments: false,
            tabular: false,
            hmm_filter: false,
            max_mx_size: 1024.0,
            trunc: false,
            passes: 3,
            threads: 1,
        }
    }
    
    pub fn validate(&self) -> Result<(), String> {
        if self.cmfile.is_empty() {
            return Err("CM file path is required".to_string());
        }
        
        if self.seqdb.is_empty() {
            return Err("Sequence database path is required".to_string());
        }
        
        if self.evalue <= 0.0 {
            return Err("E-value must be positive".to_string());
        }
        
        if self.max_mx_size <= 0.0 {
            return Err("Maximum matrix size must be positive".to_string());
        }
        
        if self.passes == 0 {
            return Err("Number of passes must be at least 1".to_string());
        }
        
        if self.threads == 0 {
            return Err("Number of threads must be at least 1".to_string());
        }
        
        Ok(())
    }
    
    pub fn get_output_path(&self) -> Option<PathBuf> {
        self.output.as_ref().map(|s| PathBuf::from(s))
    }
    
    pub fn get_cm_path(&self) -> PathBuf {
        PathBuf::from(&self.cmfile)
    }
    
    pub fn get_seqdb_path(&self) -> PathBuf {
        PathBuf::from(&self.seqdb)
    }
}

impl Default for Config {
    fn default() -> Self {
        Self::new()
    }
} 