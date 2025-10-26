#!/bin/bash

# Script to download random test images in parallel and generate inputs/outputs txt files
# Usage: ./download_test_images.sh <number_of_images> [max_parallel]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <number_of_images> [max_parallel]"
    exit 1
fi

NUM_IMAGES=$1
MAX_PARALLEL=${2:-8}  # Default to 8 parallel downloads

if ! [[ "$NUM_IMAGES" =~ ^[0-9]+$ ]] || [ "$NUM_IMAGES" -lt 1 ]; then
    echo "Error: Number of images must be a positive integer"
    exit 1
fi

if ! [[ "$MAX_PARALLEL" =~ ^[0-9]+$ ]] || [ "$MAX_PARALLEL" -lt 1 ]; then
    echo "Error: max_parallel must be a positive integer"
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

echo "Downloading $NUM_IMAGES random images with $MAX_PARALLEL parallel downloads..."

# Function to download a single image
download_image() {
    local i=$1
    local total=$2
    
    # Use picsum.photos for random images (various sizes)
    WIDTH=$((800 + RANDOM % 1200))
    HEIGHT=$((600 + RANDOM % 1000))
    
    IMAGE_FILE="$IMAGES_DIR/image_${i}.jpg"
    OUTPUT_DIR="$OUTPUTS_DIR/output_${i}"
    
    echo "[$i/$total] Downloading ${WIDTH}x${HEIGHT} image..."
    
    # Download with curl
    if curl -s -L "https://picsum.photos/${WIDTH}/${HEIGHT}" -o "$IMAGE_FILE" 2>/dev/null; then
        echo "  ✓ Saved to $IMAGE_FILE"
        return 0
    else
        echo "  ✗ Failed to download image $i"
        return 1
    fi
}

export -f download_image
export IMAGES_DIR
export OUTPUTS_DIR

# Download images in parallel using xargs
seq 1 $NUM_IMAGES | xargs -P $MAX_PARALLEL -I {} bash -c "download_image {} $NUM_IMAGES"

# Generate inputs.txt and outputs.txt after all downloads complete
echo ""
echo "Generating inputs.txt and outputs.txt..."

for i in $(seq 1 $NUM_IMAGES); do
    IMAGE_FILE="$IMAGES_DIR/image_${i}.jpg"
    OUTPUT_DIR="$OUTPUTS_DIR/output_${i}"
    
    if [ -f "$IMAGE_FILE" ]; then
        # Add to inputs.txt (absolute path)
        echo "$(pwd)/$IMAGE_FILE" >> inputs.txt
        
        # Add to outputs.txt (absolute path)
        echo "$(pwd)/$OUTPUT_DIR" >> outputs.txt
    fi
done

DOWNLOADED=$(wc -l < inputs.txt)

echo ""
echo "✓ Downloaded $DOWNLOADED/$NUM_IMAGES images to $IMAGES_DIR/"
echo "✓ Created inputs.txt with image paths"
echo "✓ Created outputs.txt with output directories"
echo ""
echo "Ready to process! Run:"
echo "  ./build/MyProject --inputs inputs.txt --outputs outputs.txt --tile-size 256"
