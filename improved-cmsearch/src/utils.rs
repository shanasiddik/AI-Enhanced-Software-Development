use anyhow::Result;
use log::{debug, info, warn};
use std::time::{Duration, Instant};

pub struct Timer {
    start: Instant,
    name: String,
}

impl Timer {
    pub fn new(name: &str) -> Self {
        Self {
            start: Instant::now(),
            name: name.to_string(),
        }
    }
    
    pub fn elapsed(&self) -> Duration {
        self.start.elapsed()
    }
    
    pub fn log_elapsed(&self) {
        let elapsed = self.elapsed();
        info!("{} completed in {:.2?}", self.name, elapsed);
    }
}

impl Drop for Timer {
    fn drop(&mut self) {
        self.log_elapsed();
    }
}

pub fn format_bytes(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;
    const GB: u64 = MB * 1024;
    
    match bytes {
        0..=KB => format!("{} B", bytes),
        KB..=MB => format!("{:.1} KB", bytes as f64 / KB as f64),
        MB..=GB => format!("{:.1} MB", bytes as f64 / MB as f64),
        _ => format!("{:.1} GB", bytes as f64 / GB as f64),
    }
}

pub fn format_time(duration: Duration) -> String {
    let secs = duration.as_secs();
    let millis = duration.subsec_millis();
    
    if secs > 0 {
        format!("{}.{:03}s", secs, millis)
    } else {
        format!("{}ms", millis)
    }
}

pub fn calculate_gc_content(sequence: &str) -> f64 {
    let gc_count = sequence.chars().filter(|&c| c == 'G' || c == 'C').count();
    gc_count as f64 / sequence.len() as f64
}

pub fn reverse_complement(sequence: &str) -> String {
    sequence.chars()
        .rev()
        .map(|c| match c {
            'A' => 'T',
            'T' => 'A',
            'G' => 'C',
            'C' => 'G',
            'U' => 'A',
            _ => c,
        })
        .collect()
}

pub fn hamming_distance(s1: &str, s2: &str) -> usize {
    s1.chars()
        .zip(s2.chars())
        .filter(|(a, b)| a != b)
        .count()
}

pub fn levenshtein_distance(s1: &str, s2: &str) -> usize {
    let len1 = s1.chars().count();
    let len2 = s2.chars().count();
    
    if len1 == 0 {
        return len2;
    }
    if len2 == 0 {
        return len1;
    }
    
    let mut matrix = vec![vec![0; len2 + 1]; len1 + 1];
    
    for i in 0..=len1 {
        matrix[i][0] = i;
    }
    for j in 0..=len2 {
        matrix[0][j] = j;
    }
    
    for (i, c1) in s1.chars().enumerate() {
        for (j, c2) in s2.chars().enumerate() {
            let cost = if c1 == c2 { 0 } else { 1 };
            matrix[i + 1][j + 1] = (matrix[i][j + 1] + 1)
                .min(matrix[i + 1][j] + 1)
                .min(matrix[i][j] + cost);
        }
    }
    
    matrix[len1][len2]
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_format_bytes() {
        assert_eq!(format_bytes(1023), "1023 B");
        assert_eq!(format_bytes(1024), "1024 B");
        assert_eq!(format_bytes(1048576), "1.0 MB");
    }
    
    #[test]
    fn test_calculate_gc_content() {
        assert_eq!(calculate_gc_content("ATGC"), 0.5);
        assert_eq!(calculate_gc_content("AAAA"), 0.0);
        assert_eq!(calculate_gc_content("GCGC"), 1.0);
    }
    
    #[test]
    fn test_reverse_complement() {
        assert_eq!(reverse_complement("ATGC"), "GCAT");
        assert_eq!(reverse_complement("AAAA"), "TTTT");
    }
    
    #[test]
    fn test_hamming_distance() {
        assert_eq!(hamming_distance("ATGC", "ATGC"), 0);
        assert_eq!(hamming_distance("ATGC", "ATCC"), 1);
        assert_eq!(hamming_distance("ATGC", "CCCC"), 3);
    }
    
    #[test]
    fn test_levenshtein_distance() {
        assert_eq!(levenshtein_distance("kitten", "sitting"), 3);
        assert_eq!(levenshtein_distance("", "abc"), 3);
        assert_eq!(levenshtein_distance("abc", ""), 3);
    }
} 