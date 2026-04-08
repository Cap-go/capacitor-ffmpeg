#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
HEADERS_DIR="$ROOT_DIR/ios/NativeCoreHeaders"
OUTPUT_DIR="$ROOT_DIR/ios/CapacitorFFmpegNativeCore.xcframework"
TEMP_DIR="$SCRIPT_DIR/target/apple-xcframework"

cd "$SCRIPT_DIR"

"$SCRIPT_DIR/apply_ffmpeg_sys_ios_sim_patch.sh"

./build_x264_ios.sh
./build_ios.sh
./build_x264_ios_sim_arm64.sh
./build_ios_sim_arm64.sh

rm -rf "$TEMP_DIR" "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

device_libs=(target/universal/release/libcapacitor_ffmpeg_rust_device.a)
device_libs+=("${(@f)$(find target/aarch64-apple-ios/release/build -path '*/out/dist/lib/*.a' | sort)}")
device_libs+=(x264-build-ios/lib/libx264.a)
libtool -static -o "$TEMP_DIR/libcapacitor_ffmpeg_native_device.a" "${device_libs[@]}"

simulator_libs=(target/universal/release/libcapacitor_ffmpeg_rust_sim_arm64.a)
simulator_libs+=("${(@f)$(find target/aarch64-apple-ios-sim/release/build -path '*/out/dist/lib/*.a' | sort)}")
simulator_libs+=(x264-build-ios-sim-arm64/lib/libx264.a)
libtool -static -o "$TEMP_DIR/libcapacitor_ffmpeg_native_sim_arm64.a" "${simulator_libs[@]}"

xcodebuild -create-xcframework \
  -library "$TEMP_DIR/libcapacitor_ffmpeg_native_device.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libcapacitor_ffmpeg_native_sim_arm64.a" -headers "$HEADERS_DIR" \
  -output "$OUTPUT_DIR"
