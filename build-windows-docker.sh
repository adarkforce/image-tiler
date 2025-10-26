#!/bin/bash

# Build for Windows using Docker (easier and more reliable)
# This creates a fully portable Windows executable with all dependencies

set -e

echo "=== Building Windows Executable using Docker ==="
echo ""

# Create Dockerfile for Windows cross-compilation
cat > Dockerfile.windows << 'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install build tools and MinGW
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    mingw-w64 \
    wget \
    unzip \
    git \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Download pre-built vips for Windows
RUN wget https://github.com/libvips/build-win64-mxe/releases/download/v8.15.2/vips-dev-w64-all-8.15.2.zip && \
    unzip vips-dev-w64-all-8.15.2.zip && \
    mv vips-dev-8.15.2 /opt/vips

# Set up environment
ENV PKG_CONFIG_PATH=/opt/vips/lib/pkgconfig
ENV PATH=/opt/vips/bin:$PATH

# Copy project files
COPY . /app
WORKDIR /app

# Create toolchain file
RUN echo 'set(CMAKE_SYSTEM_NAME Windows)' > toolchain.cmake && \
    echo 'set(CMAKE_SYSTEM_PROCESSOR x86_64)' >> toolchain.cmake && \
    echo '' >> toolchain.cmake && \
    echo 'set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)' >> toolchain.cmake && \
    echo 'set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)' >> toolchain.cmake && \
    echo 'set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)' >> toolchain.cmake && \
    echo '' >> toolchain.cmake && \
    echo 'set(CMAKE_FIND_ROOT_PATH /opt/vips)' >> toolchain.cmake && \
    echo 'set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)' >> toolchain.cmake && \
    echo 'set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)' >> toolchain.cmake && \
    echo 'set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)' >> toolchain.cmake && \
    echo '' >> toolchain.cmake && \
    echo 'set(VIPS_INCLUDE_DIR /opt/vips/include)' >> toolchain.cmake && \
    echo 'set(VIPS_LIBRARY_DIR /opt/vips/lib)' >> toolchain.cmake

# Build
RUN mkdir -p build-windows && cd build-windows && \
    cmake .. \
        -DCMAKE_TOOLCHAIN_FILE=../toolchain.cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DVIPS_INCLUDE_DIR=/opt/vips/include \
        -DVIPS_LIBRARY_DIR=/opt/vips/lib && \
    cmake --build . --config Release

# Create portable package
RUN mkdir -p /output && \
    cp build-windows/MyProject.exe /output/ && \
    cp /opt/vips/bin/*.dll /output/ 2>/dev/null || true && \
    cp download_test_images.sh /output/ && \
    cp README.md /output/

CMD ["bash"]
EOF

# Build Docker image
echo "Building Docker image (this may take 10-15 minutes)..."
docker build -f Dockerfile.windows -t myproject-windows-builder .

# Extract the built files
echo ""
echo "Extracting Windows executable and dependencies..."
rm -rf windows-portable
docker create --name temp-container myproject-windows-builder
docker cp temp-container:/output ./windows-portable
docker rm temp-container

# Create zip package
PACKAGE_NAME="MyProject-Windows-Portable-$(date +%Y%m%d).zip"
cd windows-portable
zip -r "../$PACKAGE_NAME" .
cd ..

echo ""
echo "=== Build Complete ==="
echo ""
echo "✓ Windows package created: $PACKAGE_NAME"
echo "✓ Size: $(du -h "$PACKAGE_NAME" | cut -f1)"
echo ""
echo "Transfer this ZIP file to your Windows machine via GitHub:"
echo "1. Create a new release on GitHub"
echo "2. Upload $PACKAGE_NAME as a release asset"
echo "3. Download it on your Windows machine"
echo "4. Extract and run MyProject.exe"
echo ""
echo "Package contents:"
unzip -l "$PACKAGE_NAME" | head -20
