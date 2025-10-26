#!/bin/bash

# Script to download random test images and generate inputs/outputs txt files
# Usage: ./download_test_images.sh <number_of_images>

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <number_of_images>"
    exit 1
fi

NUM_IMAGES=$1

if ! [[ "$NUM_IMAGES" =~ ^[0-9]+$ ]] || [ "$NUM_IMAGES" -lt 1 ]; then
    echo "Error: Number of images must be a positive integer"
    exit 1
fi

# Create directories
IMAGES_DIR="test_images"
OUTPUTS_DIR="test_outputs"

mkdir -p "$IMAGES_DIR"
mkdir -p "$OUTPUTS_DIR"

# Clear previous txt files
> inputs.txt
> outputs.txt

echo "Downloading $NUM_IMAGES random images..."

for i in $(seq 1 $NUM_IMAGES); do
    # Use picsum.photos for random images (various sizes)
    WIDTH=$((800 + RANDOM % 1200))
    HEIGHT=$((600 + RANDOM % 1000))
    
    IMAGE_FILE="$IMAGES_DIR/image_${i}.jpg"
    OUTPUT_DIR="$OUTPUTS_DIR/output_${i}"
    
    echo "[$i/$NUM_IMAGES] Downloading ${WIDTH}x${HEIGHT} image..."
    
    # Download with curl
    if curl -s -L "https://picsum.photos/${WIDTH}/${HEIGHT}" -o "$IMAGE_FILE"; then
        # Add to inputs.txt (absolute path)
        echo "$(pwd)/$IMAGE_FILE" >> inputs.txt
        
        # Add to outputs.txt (absolute path)
        echo "$(pwd)/$OUTPUT_DIR" >> outputs.txt
        
        echo "  ✓ Saved to $IMAGE_FILE"
    else
        echo "  ✗ Failed to download image $i"
        exit 1
    fi
    
    # Small delay to avoid rate limiting
    sleep 0.5
done

echo ""
echo "✓ Downloaded $NUM_IMAGES images to $IMAGES_DIR/"
echo "✓ Created inputs.txt with image paths"
echo "✓ Created outputs.txt with output directories"
echo ""
echo "Ready to process! Run:"
echo "  ./build/MyProject inputs.txt outputs.txt 256"
