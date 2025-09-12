#!/bin/bash

# Build script for improved-cmsearch
# This script helps build the Rust project even if Rust is not installed

set -e

echo "=== Improved cmsearch Build Script ==="
echo "Project: /clusterfs/jgi/scratch/science/mgs/nelli/shana/AI-software-development/improved-cmsearch"
echo

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "❌ Rust/Cargo not found on this system"
    echo
    echo "To install Rust, run:"
    echo "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo
    echo "Or check if Rust is available as a module:"
    echo "module avail rust"
    echo
    echo "After installing, restart your shell or run:"
    echo "source ~/.cargo/env"
    echo
    exit 1
fi

echo "✅ Rust found: $(rustc --version)"
echo "✅ Cargo found: $(cargo --version)"
echo

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ]; then
    echo "❌ Cargo.toml not found. Please run this script from the project directory."
    exit 1
fi

echo "📁 Current directory: $(pwd)"
echo "📦 Project name: $(grep '^name =' Cargo.toml | cut -d'"' -f2)"
echo

# Clean previous builds
echo "🧹 Cleaning previous builds..."
cargo clean
echo

# Check if everything compiles
echo "🔍 Checking compilation..."
if cargo check; then
    echo "✅ Compilation check passed"
else
    echo "❌ Compilation check failed"
    exit 1
fi
echo

# Run tests
echo "🧪 Running tests..."
if cargo test; then
    echo "✅ All tests passed"
else
    echo "❌ Some tests failed"
    exit 1
fi
echo

# Build debug version
echo "🔨 Building debug version..."
if cargo build; then
    echo "✅ Debug build successful"
    echo "📁 Binary location: target/debug/improved-cmsearch"
else
    echo "❌ Debug build failed"
    exit 1
fi
echo

# Build release version
echo "🚀 Building release version (optimized)..."
if cargo build --release; then
    echo "✅ Release build successful"
    echo "📁 Binary location: target/release/improved-cmsearch"
else
    echo "❌ Release build failed"
    exit 1
fi
echo

# Show binary information
if [ -f "target/release/improved-cmsearch" ]; then
    echo "📊 Binary information:"
    ls -lh target/release/improved-cmsearch
    echo
    echo "🎯 Testing binary..."
    if ./target/release/improved-cmsearch --help; then
        echo "✅ Binary works correctly"
    else
        echo "❌ Binary test failed"
        exit 1
    fi
fi

echo
echo "🎉 Build completed successfully!"
echo
echo "Usage examples:"
echo "  ./target/release/improved-cmsearch --help"
echo "  ./target/release/improved-cmsearch validate model.cm"
echo "  ./target/release/improved-cmsearch info model.cm"
echo "  ./target/release/improved-cmsearch search model.cm sequences.fasta"
echo
echo "For more information, see README.md and INSTALL.md" 