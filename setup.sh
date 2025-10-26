#!/bin/bash

# Setup script for installing dependencies
# This makes the project more portable by automating dependency installation

set -e

echo "=== MyProject Setup ==="
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected: macOS"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew is not installed"
        echo "Install it from: https://brew.sh"
        exit 1
    fi
    
    echo "Installing libvips via Homebrew..."
    brew install vips
    
    echo ""
    echo "✓ Dependencies installed"
    echo ""
    echo "Building project..."
    PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/share/pkgconfig" cmake -S . -B build
    cmake --build build
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Detected: Linux"
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        echo "Installing libvips via apt..."
        sudo apt-get update
        sudo apt-get install -y libvips-dev
    elif command -v dnf &> /dev/null; then
        echo "Installing libvips via dnf..."
        sudo dnf install -y vips-devel
    elif command -v pacman &> /dev/null; then
        echo "Installing libvips via pacman..."
        sudo pacman -S --noconfirm libvips
    else
        echo "Error: Unsupported package manager"
        echo "Please install libvips manually"
        exit 1
    fi
    
    echo ""
    echo "✓ Dependencies installed"
    echo ""
    echo "Building project..."
    cmake -S . -B build
    cmake --build build
    
else
    echo "Error: Unsupported operating system"
    exit 1
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Run the program with:"
echo "  ./build/MyProject inputs.txt outputs.txt 256"
echo ""
echo "Or test with random images:"
echo "  ./download_test_images.sh 5"
echo "  ./build/MyProject inputs.txt outputs.txt 256"
