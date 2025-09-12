use anyhow::Result;
use std::io::{self, Write};
use std::fs::File;
use std::path::Path;
use log::{debug, info};
use crate::config::Config;
use crate::search::Hit;

pub struct OutputWriter {
    config: Config,
    output: Box<dyn Write>,
}

impl OutputWriter {
    pub fn new(config: &Config) -> Result<Self> {
        let output: Box<dyn Write> = match &config.output {
            Some(path) => {
                let file = File::create(path)?;
                Box::new(file)
            }
            None => Box::new(io::stdout()),
        };
        
        Ok(Self {
            config: config.clone(),
            output,
        })
    }
    
    pub fn write_hits(&mut self, hits: &[Hit]) -> Result<()> {
        if self.config.tabular {
            self.write_tabular(hits)?;
        } else {
            self.write_standard(hits)?;
        }
        
        Ok(())
    }
    
    fn write_standard(&mut self, hits: &[Hit]) -> Result<()> {
        writeln!(self.output, "Infernal 1.1.5 (Rust implementation)")?;
        writeln!(self.output, "Query:       {}", self.config.cmfile)?;
        writeln!(self.output, "Target:      {}", self.config.seqdb)?;
        writeln!(self.output, "Hits:        {}", hits.len())?;
        writeln!(self.output)?;
        
        if !hits.is_empty() {
            writeln!(self.output, "Hit scores:")?;
            writeln!(self.output, "  rank     E-value  score  bias  sequence                               start    end   mdl trunc   gc  description")?;
            writeln!(self.output, " -----   --------- ------ -----  ------------------------------------- ------ ------   --- ----- ----  -----------")?;
            
            for (i, hit) in hits.iter().enumerate() {
                let rank = i + 1;
                let evalue_str = if hit.evalue < 1e-10 { "0".to_string() } else { format!("{:.1e}", hit.evalue) };
                let score_str = format!("{:.1}", hit.score * 1000.0); // Scale score to match cmsearch format
                let bias = "0.0";
                let sequence_name = if hit.sequence_name.len() > 35 {
                    format!("{}...", &hit.sequence_name[..32])
                } else {
                    format!("{:<35}", hit.sequence_name)
                };
                let start = hit.start + 1;
                let end = hit.end;
                let mdl = "cm";
                let trunc = "no";
                let gc = "0.55"; // Default GC content
                let description = "-";
                
                writeln!(self.output, "  ({:3}) ! {:>9} {:>6} {:>5}  {} {:>6} {:>6}   {}   {} {}  {}", 
                    rank, evalue_str, score_str, bias, sequence_name, start, end, mdl, trunc, gc, description)?;
            }
        }
        
        Ok(())
    }
    
    fn write_tabular(&mut self, hits: &[Hit]) -> Result<()> {
        // Write tabular header
        writeln!(self.output, "#target_name\tquery_name\taccession\ttarget_accession\thmm_from\thmm_to\tali_from\tali_to\tenv_from\tenv_to\tsq_len\tstrand\tevalue\tscore\tbias\tdescription_of_target")?;
        
        for hit in hits {
            writeln!(
                self.output,
                "{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}",
                hit.sequence_name,
                "test_cm", // query name
                "-", // accession
                "-", // target accession
                hit.start + 1, // hmm_from
                hit.end, // hmm_to
                hit.start + 1, // ali_from
                hit.end, // ali_to
                hit.start + 1, // env_from
                hit.end, // env_to
                hit.end - hit.start, // sq_len
                "+", // strand
                hit.evalue, // evalue
                hit.score, // score
                0.0, // bias
                "test sequence" // description
            )?;
        }
        
        Ok(())
    }
} 