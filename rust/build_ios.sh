#!/bin/bash

# Build script for iOS device only

set -e

# Allow pkg-config to work when cross-compiling
export PKG_CONFIG_ALLOW_CROSS=1

echo "Building Rust library for iOS device only..."

# Install iOS device target if not already installed
echo "Adding iOS device target..."
rustup target add aarch64-apple-ios

# Set environment for iOS device SDK
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
export IPHONEOS_DEPLOYMENT_TARGET="11.0"

# Build for iOS device (ARM64) only
echo "Building for iOS device (aarch64-apple-ios)..."
SDKROOT="$IOS_SDK" \
CC="$(xcrun --sdk iphoneos --find clang)" \
CFLAGS="-arch arm64 -isysroot $IOS_SDK" \
cargo build --release --target aarch64-apple-ios

echo "Creating output directory..."
mkdir -p target/universal/release

# Copy device library
cp target/aarch64-apple-ios/release/libcapacitor_ffmpeg_rust.a target/universal/release/libcapacitor_ffmpeg_rust_device.a

echo "Build complete!"
echo "Library created:"
echo "- Device: target/universal/release/libcapacitor_ffmpeg_rust_device.a" 