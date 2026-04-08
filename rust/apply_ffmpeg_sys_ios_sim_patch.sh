#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_DIR="$SCRIPT_DIR/ffmpeg-sys"
PATCH_PATH="$SCRIPT_DIR/patches/ffmpeg-sys-ios-sim.patch"

if [ ! -d "$SUBMODULE_DIR" ] || [ ! -f "$SUBMODULE_DIR/build.rs" ]; then
    echo "Error: ffmpeg-sys submodule is missing at $SUBMODULE_DIR"
    exit 1
fi

if [ ! -f "$PATCH_PATH" ]; then
    echo "Error: patch file is missing at $PATCH_PATH"
    exit 1
fi

if git -C "$SUBMODULE_DIR" apply --reverse --check "$PATCH_PATH" >/dev/null 2>&1; then
    echo "ffmpeg-sys iOS simulator patch already applied"
    exit 0
fi

if git -C "$SUBMODULE_DIR" apply --check "$PATCH_PATH" >/dev/null 2>&1; then
    git -C "$SUBMODULE_DIR" apply "$PATCH_PATH"
    echo "Applied ffmpeg-sys iOS simulator patch"
    exit 0
fi

echo "Error: ffmpeg-sys iOS simulator patch could not be applied cleanly"
exit 1
