#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/maestro"
REPORT_PATH="$OUTPUT_DIR/ios-report.xml"
ARTIFACT_DIR="$OUTPUT_DIR/ios-artifacts"
DEVICE_ID="${BOOTED_SIMULATOR_ID:-${MAESTRO_IOS_DEVICE:-}}"
DRIVER_TIMEOUT_MS="${MAESTRO_DRIVER_STARTUP_TIMEOUT:-180000}"

mkdir -p "$OUTPUT_DIR" "$ARTIFACT_DIR"

export MAESTRO_DRIVER_STARTUP_TIMEOUT="$DRIVER_TIMEOUT_MS"

COMMAND=(
  maestro
  test
  -p
  ios
  --format
  junit
  --output
  "$REPORT_PATH"
  --test-output-dir
  "$ARTIFACT_DIR"
)

if [[ -n "$DEVICE_ID" ]]; then
  COMMAND+=(--device "$DEVICE_ID")
fi

COMMAND+=(
  "$ROOT_DIR/.maestro/runtime-checks.yaml"
  "$ROOT_DIR/.maestro/image-conversion.yaml"
  "$ROOT_DIR/.maestro/video-reencode.yaml"
)

"${COMMAND[@]}"
