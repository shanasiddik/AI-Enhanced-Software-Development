# Installation Guide for Improved cmsearch

## Prerequisites

### Installing Rust

If Rust is not installed on your system, you can install it using rustup:

```bash
# Install rustup (Rust toolchain installer)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow the prompts and restart your shell or run:
source ~/.cargo/env

# Verify installation
rustc --version
cargo --version
```

### Alternative: Using a module system (if available)

If your system uses environment modules:

```bash
# Check available Rust modules
module avail rust

# Load Rust module
module load rust

# Or load a specific version
module load rust/1.70.0
```

## Building the Project

### 1. Navigate to the project directory

```bash
cd /clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-software-development/improved-cmsearch
```

### 2. Build the project

```bash
# Check if everything compiles
cargo check

# Build in debug mode
cargo build

# Build in release mode (optimized)
cargo build --release
```

### 3. Run tests

```bash
# Run all tests
cargo test

# Run tests with output
cargo test -- --nocapture
```

### 4. Install (optional)

```bash
# Install to cargo bin directory
cargo install --path .

# Or copy the binary to a custom location
cp target/release/improved-cmsearch /path/to/your/bin/
```

## Usage Examples

### Basic usage

```bash
# Show help
./target/release/improved-cmsearch --help

# Validate a CM file
./target/release/improved-cmsearch validate model.cm

# Show CM information
./target/release/improved-cmsearch info model.cm

# Search (with example files)
./target/release/improved-cmsearch search model.cm sequences.fasta
```

### Advanced usage

```bash
# Parallel processing
./target/release/improved-cmsearch search model.cm sequences.fasta --threads 8

# Custom thresholds
./target/release/improved-cmsearch search model.cm sequences.fasta -E 1e-5 -T 10.0

# Tabular output
./target/release/improved-cmsearch search model.cm sequences.fasta -t

# Verbose logging
./target/release/improved-cmsearch search model.cm sequences.fasta -v
```

## Troubleshooting

### Common Issues

1. **"command not found: cargo"**
   - Install Rust using the instructions above
   - Make sure your PATH includes `~/.cargo/bin`

2. **"rustc: command not found"**
   - Install Rust using rustup
   - Restart your shell or run `source ~/.cargo/env`

3. **Permission denied**
   - Make sure you have write permissions to the project directory
   - Check if you need to use `sudo` for system-wide installation

4. **Out of memory during build**
   - Use `cargo build --release` for optimized builds
   - Increase available memory or use swap

### System-specific Notes

#### Linux (CentOS/RHEL)

```bash
# Install development tools
sudo yum groupinstall "Development Tools"

# Install additional dependencies
sudo yum install openssl-devel
```

#### Linux (Ubuntu/Debian)

```bash
# Install development tools
sudo apt-get update
sudo apt-get install build-essential

# Install additional dependencies
sudo apt-get install libssl-dev pkg-config
```

#### macOS

```bash
# Install Xcode command line tools
xcode-select --install

# Install additional dependencies via Homebrew
brew install openssl
```

## Performance Tuning

### Build Optimizations

```bash
# Set environment variables for optimal performance
export RUSTFLAGS="-C target-cpu=native"
export CARGO_PROFILE_RELEASE_OPT_LEVEL=3
export CARGO_PROFILE_RELEASE_LTO=true

# Build with optimizations
cargo build --release
```

### Runtime Optimizations

```bash
# Set number of threads based on your system
export RAYON_NUM_THREADS=8

# Run with optimized settings
./target/release/improved-cmsearch search model.cm sequences.fasta --threads 8
```

## Development Setup

### IDE Setup

1. **VS Code**
   ```bash
   # Install Rust extension
   code --install-extension rust-lang.rust-analyzer
   ```

2. **IntelliJ IDEA / CLion**
   - Install Rust plugin
   - Configure Rust toolchain

### Debugging

```bash
# Build with debug symbols
cargo build

# Run with debug output
RUST_LOG=debug ./target/debug/improved-cmsearch search model.cm sequences.fasta

# Use gdb for debugging
gdb --args ./target/debug/improved-cmsearch search model.cm sequences.fasta
```

## Dependencies

The project uses the following key dependencies:

- **clap**: Command-line argument parsing
- **rayon**: Parallel processing
- **anyhow**: Error handling
- **serde**: Serialization
- **log**: Logging
- **bio**: Bioinformatics utilities

All dependencies are managed by Cargo and will be automatically downloaded during the build process. 