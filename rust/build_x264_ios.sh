#!/bin/bash

# Build script for x264 iOS device only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
X264_DIR="$SCRIPT_DIR/rust/x264"
OUTPUT_DIR="$SCRIPT_DIR/x264-build-ios"

echo "Building x264 for iOS device only..."

# Check if x264 directory exists
if [ ! -d "$X264_DIR" ]; then
    echo "Error: x264 directory not found at $X264_DIR"
    exit 1
fi

# Clean previous builds
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$X264_DIR"

# Clean any previous builds
make clean || true
rm -f config.h config.mak config.log x264.pc x264.def || true

# Set iOS SDK environment
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
export IPHONEOS_DEPLOYMENT_TARGET="11.0"

echo "Using iOS SDK: $IOS_SDK"

# Get iOS toolchain tools
CC=$(xcrun --sdk iphoneos --find clang)
AR=$(xcrun --sdk iphoneos --find ar)
RANLIB=$(xcrun --sdk iphoneos --find ranlib)
STRIP=$(xcrun --sdk iphoneos --find strip)

export CC AR RANLIB STRIP

# Configure for iOS device (ARM64) cross-compilation
echo "Configuring x264 for iOS device (aarch64-apple-ios)..."

# Set cross-compilation flags
export CFLAGS="-arch arm64 -isysroot $IOS_SDK -miphoneos-version-min=11.0 -fembed-bitcode -DTARGET_OS_IPHONE=1"
export LDFLAGS="-arch arm64 -isysroot $IOS_SDK -miphoneos-version-min=11.0"

./configure \
    --host=aarch64-apple-darwin \
    --sysroot="$IOS_SDK" \
    --enable-static \
    --disable-shared \
    --disable-cli \
    --disable-asm \
    --enable-pic \
    --disable-opencl \
    --prefix="$OUTPUT_DIR"

echo "Building x264..."
# Use sysctl on macOS to get CPU count
NCPU=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
make -j$NCPU

echo "Installing x264..."
make install

echo "x264 iOS build complete!"
echo "Static library: $OUTPUT_DIR/lib/libx264.a"
echo "Headers: $OUTPUT_DIR/include/"

# Verify the build
if [ -f "$OUTPUT_DIR/lib/libx264.a" ]; then
    echo "✓ Static library built successfully"
    # Show library info
    file "$OUTPUT_DIR/lib/libx264.a"
    lipo -info "$OUTPUT_DIR/lib/libx264.a"
else
    echo "✗ Build failed - static library not found"
    exit 1
fi

# List what was built
echo "Built files:"
ls -la "$OUTPUT_DIR/lib/"
ls -la "$OUTPUT_DIR/include/" 