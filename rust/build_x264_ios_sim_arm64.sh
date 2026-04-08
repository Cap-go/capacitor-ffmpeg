#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
X264_DIR="$SCRIPT_DIR/rust/x264"
OUTPUT_DIR="$SCRIPT_DIR/x264-build-ios-sim-arm64"

echo "Building x264 for iOS Simulator ARM64..."

if [ ! -d "$X264_DIR" ]; then
    echo "Error: x264 directory not found at $X264_DIR"
    exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$X264_DIR"

make clean || true
rm -f config.h config.mak config.log x264.pc x264.def || true

IOSSIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
export IPHONEOS_DEPLOYMENT_TARGET="15.0"

CC=$(xcrun --sdk iphonesimulator --find clang)
AR=$(xcrun --sdk iphonesimulator --find ar)
RANLIB=$(xcrun --sdk iphonesimulator --find ranlib)
STRIP=$(xcrun --sdk iphonesimulator --find strip)

export CC AR RANLIB STRIP
export CFLAGS="-arch arm64 -isysroot $IOSSIM_SDK -mios-simulator-version-min=15.0 -DTARGET_OS_SIMULATOR=1"
export LDFLAGS="-arch arm64 -isysroot $IOSSIM_SDK -mios-simulator-version-min=15.0"

./configure \
    --host=aarch64-apple-darwin \
    --sysroot="$IOSSIM_SDK" \
    --enable-static \
    --disable-cli \
    --disable-asm \
    --enable-pic \
    --disable-opencl \
    --prefix="$OUTPUT_DIR"

NCPU=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
make -j"$NCPU"
make install

echo "x264 iOS simulator build complete"
echo "Static library: $OUTPUT_DIR/lib/libx264.a"
