#!/bin/bash

set -e

export PKG_CONFIG_ALLOW_CROSS=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
X264_PKGCONFIG_DIR="$SCRIPT_DIR/x264-build-ios-sim-arm64/lib/pkgconfig"

"$SCRIPT_DIR/apply_ffmpeg_sys_ios_sim_patch.sh"

if [ -d "$X264_PKGCONFIG_DIR" ]; then
    export PKG_CONFIG_PATH="${X264_PKGCONFIG_DIR}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
fi

echo "Building Rust library for iOS simulator ARM64..."

rustup target add aarch64-apple-ios-sim

IOSSIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
export IPHONEOS_DEPLOYMENT_TARGET="15.0"

SDKROOT="$IOSSIM_SDK" \
CC="$(xcrun --sdk iphonesimulator --find clang)" \
CFLAGS="-arch arm64 -isysroot $IOSSIM_SDK -mios-simulator-version-min=15.0" \
cargo build --release --target aarch64-apple-ios-sim

mkdir -p target/universal/release
cp target/aarch64-apple-ios-sim/release/libcapacitor_ffmpeg_rust.a target/universal/release/libcapacitor_ffmpeg_rust_sim_arm64.a

echo "Build complete!"
echo "- Simulator: target/universal/release/libcapacitor_ffmpeg_rust_sim_arm64.a"
