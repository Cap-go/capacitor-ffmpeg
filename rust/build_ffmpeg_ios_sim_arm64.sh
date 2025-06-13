#!/bin/bash

# Build script for FFmpeg iOS Simulator ARM64 (aarch64-apple-ios-sim)

set -e

echo "Building FFmpeg for iOS Simulator ARM64 (aarch64-apple-ios-sim)..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FFMPEG_SRC_DIR="$SCRIPT_DIR/ffmpeg"
BUILD_OUTPUT_DIR="$SCRIPT_DIR/ffmpeg-build-ios-sim-arm64"

# Check if already built
if [ -d "$BUILD_OUTPUT_DIR/lib" ] && [ -f "$BUILD_OUTPUT_DIR/lib/libavcodec.a" ]; then
    echo "FFmpeg already built for iOS Simulator ARM64. Skipping..."
    echo "Built libraries location: $BUILD_OUTPUT_DIR"
    exit 0
fi

# Check for Xcode
if ! command -v xcrun &> /dev/null; then
    echo "Error: Xcode command line tools not found"
    exit 1
fi

# Check if ffmpeg source exists
if [ ! -d "$FFMPEG_SRC_DIR" ]; then
    echo "Error: FFmpeg source directory not found at $FFMPEG_SRC_DIR"
    exit 1
fi

# Get iOS Simulator SDK path
IOSSIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
if [ ! -d "$IOSSIM_SDK" ]; then
    echo "Error: iOS Simulator SDK not found"
    exit 1
fi

echo "Using iOS Simulator SDK: $IOSSIM_SDK"

# Set target and deployment target
TARGET="aarch64-apple-ios-sim"
IOS_MIN_VERSION="11.0"

# Set up environment variables for cross-compilation
export CC=$(xcrun --sdk iphonesimulator --find clang)
export CXX=$(xcrun --sdk iphonesimulator --find clang++)
export AR=$(xcrun --sdk iphonesimulator --find ar)
export RANLIB=$(xcrun --sdk iphonesimulator --find ranlib)
export STRIP=$(xcrun --sdk iphonesimulator --find strip)

# Compiler flags for iOS Simulator ARM64
export CFLAGS="-arch arm64 -isysroot $IOSSIM_SDK -mios-simulator-version-min=$IOS_MIN_VERSION -fembed-bitcode"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch arm64 -isysroot $IOSSIM_SDK -mios-simulator-version-min=$IOS_MIN_VERSION"

# Create and enter build directory
BUILD_DIR="$FFMPEG_SRC_DIR/build-ios-sim-arm64"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Configuring FFmpeg..."

# Configure FFmpeg for iOS Simulator ARM64
../configure \
    --enable-cross-compile \
    --target-os=darwin \
    --arch=aarch64 \
    --sysroot="$IOSSIM_SDK" \
    --cc="$CC" \
    --cxx="$CXX" \
    --ar="$AR" \
    --ranlib="$RANLIB" \
    --strip="$STRIP" \
    --extra-cflags="$CFLAGS" \
    --extra-cxxflags="$CXXFLAGS" \
    --extra-ldflags="$LDFLAGS" \
    --prefix="$BUILD_OUTPUT_DIR" \
    --enable-static \
    --disable-shared \
    --disable-programs \
    --disable-doc \
    --disable-htmlpages \
    --disable-manpages \
    --disable-podpages \
    --disable-txtpages \
    --disable-debug \
    --disable-stripping \
    --enable-pic \
    --disable-network \
    --disable-autodetect \
    --enable-small \
    --disable-hwaccels \
    --disable-devices \
    --disable-filters \
    --enable-filter=scale \
    --enable-filter=fps \
    --enable-filter=format \
    --enable-filter=transpose \
    --enable-filter=crop \
    --enable-filter=pad \
    --disable-decoders \
    --enable-decoder=h264 \
    --enable-decoder=hevc \
    --enable-decoder=aac \
    --enable-decoder=mp3 \
    --enable-decoder=pcm_s16le \
    --disable-encoders \
    --enable-encoder=libx264 \
    --enable-encoder=aac \
    --enable-encoder=pcm_s16le \
    --disable-muxers \
    --enable-muxer=mp4 \
    --enable-muxer=mov \
    --disable-demuxers \
    --enable-demuxer=mov \
    --enable-demuxer=mp4 \
    --enable-demuxer=aac \
    --enable-demuxer=mp3 \
    --disable-protocols \
    --enable-protocol=file

echo "Building FFmpeg..."
make -j$(sysctl -n hw.ncpu)

echo "Installing FFmpeg..."
make install

echo "FFmpeg build complete for iOS Simulator ARM64!"
echo "Libraries installed in: $BUILD_OUTPUT_DIR"
echo ""
echo "Static libraries:"
find "$BUILD_OUTPUT_DIR/lib" -name "*.a" -exec echo "  {}" \; 