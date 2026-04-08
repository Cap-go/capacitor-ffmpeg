#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/maestro"
REPORT_PATH="$OUTPUT_DIR/android-report.xml"
ARTIFACT_DIR="$OUTPUT_DIR/android-artifacts"
DRIVER_DIR="${TMPDIR:-/tmp}/maestro-android-driver"
DEVICE_ID="${ANDROID_SERIAL:-$(adb devices | awk 'NR>1 && $2 == "device" { print $1; exit }')}"
DRIVER_LOG="$OUTPUT_DIR/android-driver.log"

if [[ -z "$DEVICE_ID" ]]; then
  echo "No Android device is available for Maestro."
  exit 1
fi

if [[ ! -f "$HOME/.maestro/lib/maestro-client.jar" ]]; then
  echo "Maestro CLI is not installed at $HOME/.maestro."
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$ARTIFACT_DIR"

# Local runs can leave the iOS Maestro runner bound to port 7001.
pkill -f "maestro-driver-iosUITests-Runner" >/dev/null 2>&1 || true

rm -rf "$DRIVER_DIR"
mkdir -p "$DRIVER_DIR"
(
  cd "$DRIVER_DIR"
  jar xf "$HOME/.maestro/lib/maestro-client.jar" maestro-app.apk maestro-server.apk
)

adb -s "$DEVICE_ID" wait-for-device
adb -s "$DEVICE_ID" install -r "$DRIVER_DIR/maestro-app.apk" >/dev/null
adb -s "$DEVICE_ID" install -r "$DRIVER_DIR/maestro-server.apk" >/dev/null
adb -s "$DEVICE_ID" shell am force-stop dev.mobile.maestro >/dev/null 2>&1 || true
adb -s "$DEVICE_ID" shell am force-stop dev.mobile.maestro.test >/dev/null 2>&1 || true

: >"$DRIVER_LOG"
adb -s "$DEVICE_ID" shell am instrument -w dev.mobile.maestro.test/androidx.test.runner.AndroidJUnitRunner >"$DRIVER_LOG" 2>&1 &
DRIVER_PID=$!

cleanup() {
  kill "$DRIVER_PID" >/dev/null 2>&1 || true
  adb -s "$DEVICE_ID" forward --remove tcp:7001 >/dev/null 2>&1 || true
  adb -s "$DEVICE_ID" shell am force-stop dev.mobile.maestro >/dev/null 2>&1 || true
  adb -s "$DEVICE_ID" shell am force-stop dev.mobile.maestro.test >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in $(seq 1 20); do
  if adb -s "$DEVICE_ID" shell ps -A | grep -q 'dev.mobile.maestro'; then
    DRIVER_READY=1
    break
  fi
  sleep 1
done

if [[ "${DRIVER_READY:-0}" -ne 1 ]]; then
  echo "Maestro Android driver did not start on device $DEVICE_ID." >&2
  cat "$DRIVER_LOG" >&2 || true
  exit 1
fi

adb -s "$DEVICE_ID" forward --remove tcp:7001 >/dev/null 2>&1 || true
adb -s "$DEVICE_ID" forward tcp:7001 tcp:7001 >/dev/null
sleep 2

JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true maestro test \
  --no-reinstall-driver \
  -p android \
  --device "$DEVICE_ID" \
  --format junit \
  --output "$REPORT_PATH" \
  --test-output-dir "$ARTIFACT_DIR" \
  "$ROOT_DIR/.maestro/runtime-checks.yaml" \
  "$ROOT_DIR/.maestro/image-conversion.yaml" \
  "$ROOT_DIR/.maestro/unsupported-reencode-android.yaml"
