# MyProject

A CMake project with libvips for batch image processing using dzsave.

## Quick Setup

Automated setup (installs dependencies and builds):

```bash
chmod +x setup.sh
./setup.sh
```

## Manual Setup

### Prerequisites

Install libvips on your system:

**macOS:**

```bash
brew install vips
```

**Ubuntu/Debian:**

```bash
sudo apt-get install libvips-dev
```

**Fedora:**

```bash
sudo dnf install vips-devel
```

**Arch Linux:**

```bash
sudo pacman -S libvips
```

### Build

**macOS:**

```bash
PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/share/pkgconfig" cmake -S . -B build
cmake --build build
```

**Linux:**

```bash
cmake -S . -B build
cmake --build build
```

## Docker

For maximum portability, use Docker:

```bash
docker build -t image-processor .
docker run -v $(pwd)/test_images:/app/test_images -v $(pwd)/test_outputs:/app/test_outputs image-processor ./build/MyProject --inputs inputs.txt --outputs outputs.txt --tile-size 256
```

## Usage

1. Create `inputs.txt` with your input image paths (one per line)
2. Create `outputs.txt` with corresponding output folder paths (one per line)
3. Run the program:

```bash
./build/MyProject --inputs inputs.txt --outputs outputs.txt [OPTIONS]
```

### Options:

- `--inputs <file>` - Input file with image paths (required)
- `--outputs <file>` - Output file with tile folder paths (required)
- `--tile-size <int>` - Tile size (default: 512)
- `--suffix <ext>` - Tile format: .png, .jpg, .jpeg (default: .jpg)
- `--jpeg-quality <int>` - JPEG quality 1-100 (default: 85)
- `--threads <int>` - Number of parallel workers (default: hardware concurrency)
- `--keep-tiles` - Keep original tile files after merging (default: false)
- `--help` - Show help message

### Example:

```bash
./build/MyProject --inputs inputs.txt --outputs outputs.txt --tile-size 256 --suffix .jpg --jpeg-quality 90 --threads 8
```

### Output

For each image, the program generates:

- `tiles_000.binz` - Binary file containing all gzip-compressed tiles
- `metadata.json` - JSON file with tile locations and dimensions

The metadata.json format:

```json
{
  "width": 2048,
  "height": 2048,
  "tile_size": 512,
  "tiles": {
    "0_0_0": {
      "binaryName": "tiles_000.binz",
      "startOffset": 0,
      "size": 12345
    }
  }
}
```

## Example

**inputs.txt:**

```text
/path/to/image1.jpg
/path/to/image2.png
```

**outputs.txt:**

```text
/path/to/output1
/path/to/output2
```

The program will process each image with dzsave using Google layout, onetile depth, and skip blank tiles.

## Quick Test

Download random test images and generate input/output files:

```bash
./download_test_images.sh 5
./build/MyProject --inputs inputs.txt --outputs outputs.txt --tile-size 256
```
