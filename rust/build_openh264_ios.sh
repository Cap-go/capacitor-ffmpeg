#!/bin/bash

# Build OpenH264 for iOS targets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENH264_DIR="$SCRIPT_DIR/openh264"
OUTPUT_DIR="$SCRIPT_DIR/openh264-build-ios"

echo "Building OpenH264 for iOS..."

# Clean previous builds
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$OPENH264_DIR"

# Clean any previous builds
make clean || true

echo "Building OpenH264 for iOS device (arm64)..."

# Build for iOS device (arm64) 
# Use sysctl on macOS instead of nproc
NCPU=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
make OS=ios ARCH=arm64 SDK_MIN=11.0 -j$NCPU

# Copy the built libraries
mkdir -p "$OUTPUT_DIR/lib"
mkdir -p "$OUTPUT_DIR/include"

# Find and copy the built library
find . -name "*.a" -exec cp {} "$OUTPUT_DIR/lib/" \;

# Copy headers
cp -r codec/api/wels/*.h "$OUTPUT_DIR/include/"

# Create pkg-config file for OpenH264
cat > "$OUTPUT_DIR/openh264.pc" << EOF
prefix=$OUTPUT_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: openh264
Description: Open Source H.264 Codec
Version: 2.6.0
Libs: -L\${libdir} -lopenh264
Cflags: -I\${includedir}
EOF

echo "OpenH264 iOS build complete!"
echo "Libraries: $OUTPUT_DIR/lib/"
echo "Headers: $OUTPUT_DIR/include/"

# List what was built
ls -la "$OUTPUT_DIR/lib/"
ls -la "$OUTPUT_DIR/include/" 