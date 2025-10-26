#!/bin/bash

# Cross-compile for Windows from macOS using MinGW
# Creates a portable Windows package with all dependencies

set -e

echo "=== Windows Cross-Compilation Setup ==="
echo ""

# Check if mingw-w64 is installed
if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
    echo "Installing MinGW-w64 toolchain..."
    brew install mingw-w64
fi

# Install dependencies for cross-compilation
echo "Installing build dependencies..."
brew install cmake meson ninja pkg-config

# Create build directory
BUILD_DIR="build-windows"
INSTALL_DIR="$(pwd)/windows-portable"
DEPS_DIR="$(pwd)/deps-windows"

rm -rf "$BUILD_DIR" "$INSTALL_DIR" "$DEPS_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$DEPS_DIR"

echo ""
echo "=== Building libvips and dependencies for Windows ==="
echo ""
echo "This will take 15-30 minutes..."
echo ""

# Set up cross-compilation environment
export PKG_CONFIG_PATH="$DEPS_DIR/lib/pkgconfig"
export MINGW_PREFIX="x86_64-w64-mingw32"
export CC="$MINGW_PREFIX-gcc"
export CXX="$MINGW_PREFIX-g++"
export AR="$MINGW_PREFIX-ar"
export RANLIB="$MINGW_PREFIX-ranlib"
export STRIP="$MINGW_PREFIX-strip"

# Create a meson cross file
cat > "$BUILD_DIR/cross-mingw.txt" << EOF
[binaries]
c = '$MINGW_PREFIX-gcc'
cpp = '$MINGW_PREFIX-g++'
ar = '$MINGW_PREFIX-ar'
strip = '$MINGW_PREFIX-strip'
pkgconfig = 'pkg-config'

[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'

[properties]
sys_root = '/usr/local/opt/mingw-w64'
EOF

echo "Cross-compilation is complex. Using pre-built vips binaries instead..."
echo ""
echo "Please download the Windows vips binary from:"
echo "https://github.com/libvips/build-win64-mxe/releases"
echo ""
echo "Extract it and place the contents in: $DEPS_DIR"
echo ""
read -p "Press Enter after you've downloaded and extracted vips-dev-w64-all..."

# Build the project
echo ""
echo "Building MyProject for Windows..."

cd "$BUILD_DIR"

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

cmake --build . --config Release

# Copy executable
cp MyProject.exe "$INSTALL_DIR/"

# Copy DLLs
echo "Copying required DLLs..."
cp "$DEPS_DIR/bin/"*.dll "$INSTALL_DIR/" 2>/dev/null || true

# Create package
cd "$INSTALL_DIR/.."
PACKAGE_NAME="MyProject-Windows-$(date +%Y%m%d).zip"
zip -r "$PACKAGE_NAME" "$(basename $INSTALL_DIR)"

echo ""
echo "=== Build Complete ==="
echo ""
echo "Windows package created: $PACKAGE_NAME"
echo "Transfer this to your Windows machine and extract it."
