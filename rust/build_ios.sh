#!/bin/bash

# Build script for iOS targets

set -e

# Allow pkg-config to work when cross-compiling
export PKG_CONFIG_ALLOW_CROSS=1

echo "Building Rust library for iOS..."

# Build FFmpeg for iOS simulator ARM64 first
echo "Building FFmpeg for iOS simulator ARM64..."
./build_ffmpeg_ios_sim_arm64.sh

# Get script directory for FFMPEG_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install iOS targets if not already installed
echo "Adding iOS targets..."
rustup target add aarch64-apple-ios
rustup target add x86_64-apple-ios
rustup target add aarch64-apple-ios-sim

# Build for iOS device (ARM64)
echo "Building for iOS device (aarch64-apple-ios)..."
cargo build --release --target aarch64-apple-ios

# Build for iOS simulator (x86_64)
echo "Building for iOS simulator (x86_64-apple-ios)..."
cargo build --release --target x86_64-apple-ios

# Build for iOS simulator (ARM64 - M1 Macs) with prebuilt FFmpeg
echo "Building for iOS simulator ARM64 (aarch64-apple-ios-sim)..."
# Set environment for iOS simulator SDK (not device SDK)
IOSSIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
# Unset macOS deployment target to avoid conflicts
unset MACOSX_DEPLOYMENT_TARGET
# Set additional environment variables for bindgen and ffmpeg-sys
FFMPEG_DIR="$SCRIPT_DIR/ffmpeg-build-ios-sim-arm64" \
SYSROOT="$IOSSIM_SDK" \
SDKROOT="$IOSSIM_SDK" \
IPHONEOS_DEPLOYMENT_TARGET="11.0" \
CC_aarch64_apple_darwin="$(xcrun --sdk iphonesimulator --find clang)" \
CFLAGS_aarch64_apple_darwin="-arch arm64 -isysroot $IOSSIM_SDK -mios-simulator-version-min=11.0" \
CC="$(xcrun --sdk iphonesimulator --find clang)" \
HOST_CC="$(xcrun --sdk iphonesimulator --find clang)" \
CFLAGS="-arch arm64 -isysroot $IOSSIM_SDK -mios-simulator-version-min=11.0" \
HOST_CFLAGS="-arch arm64 -isysroot $IOSSIM_SDK -mios-simulator-version-min=11.0" \
CARGO_FEATURE_STATIC=1 \
cargo build --release --target aarch64-apple-ios-sim -vv

echo "Creating universal library..."
mkdir -p target/universal/release

# Create universal library for simulator
lipo -create \
    target/x86_64-apple-ios/release/libcapacitor_ffmpeg_rust.a \
    target/aarch64-apple-ios-sim/release/libcapacitor_ffmpeg_rust.a \
    -output target/universal/release/libcapacitor_ffmpeg_rust_sim.a

# Copy device library
cp target/aarch64-apple-ios/release/libcapacitor_ffmpeg_rust.a target/universal/release/libcapacitor_ffmpeg_rust_device.a

echo "Build complete!"
echo "Libraries created:"
echo "- Device: target/universal/release/libcapacitor_ffmpeg_rust_device.a"
echo "- Simulator: target/universal/release/libcapacitor_ffmpeg_rust_sim.a" 