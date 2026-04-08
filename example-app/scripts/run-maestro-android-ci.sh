#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT_DIR/android"
OUTPUT_DIR="$ROOT_DIR/build/maestro"
EMULATOR_LOG="$OUTPUT_DIR/android-emulator.log"

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/usr/local/lib/android/sdk}}"

ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-34}"
ANDROID_EMULATOR_ARCH="${ANDROID_EMULATOR_ARCH:-x86_64}"
ANDROID_EMULATOR_DEVICE="${ANDROID_EMULATOR_DEVICE:-pixel_6}"
ANDROID_EMULATOR_NAME="${ANDROID_EMULATOR_NAME:-maestro-ci}"
ANDROID_EMULATOR_PORT="${ANDROID_EMULATOR_PORT:-5554}"
ANDROID_SERIAL="emulator-${ANDROID_EMULATOR_PORT}"
ANDROID_BOOT_TIMEOUT_SECONDS="${ANDROID_BOOT_TIMEOUT_SECONDS:-420}"

mkdir -p "$OUTPUT_DIR"

find_sdk_tool() {
  local tool="$1"
  local candidate

  if candidate="$(command -v "$tool" 2>/dev/null)"; then
    echo "$candidate"
    return 0
  fi

  for candidate in \
    "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/$tool" \
    "$ANDROID_SDK_ROOT/cmdline-tools"/*/bin/"$tool" \
    "$ANDROID_SDK_ROOT/emulator/$tool" \
    "$ANDROID_SDK_ROOT/platform-tools/$tool"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

SDKMANAGER="$(find_sdk_tool sdkmanager || true)"
AVDMANAGER="$(find_sdk_tool avdmanager || true)"
EMULATOR_BIN="$(find_sdk_tool emulator || true)"
ADB_BIN="$(find_sdk_tool adb || true)"

if [[ -z "$SDKMANAGER" || -z "$AVDMANAGER" || -z "$EMULATOR_BIN" || -z "$ADB_BIN" ]]; then
  echo "Android SDK tools are missing under $ANDROID_SDK_ROOT." >&2
  exit 1
fi

install_system_image() {
  local candidate

  yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true

  for candidate in \
    "system-images;android-${ANDROID_API_LEVEL};google_atd;${ANDROID_EMULATOR_ARCH}" \
    "system-images;android-${ANDROID_API_LEVEL};google_apis;${ANDROID_EMULATOR_ARCH}"; do
    if yes | "$SDKMANAGER" --install \
      "platform-tools" \
      "emulator" \
      "platforms;android-${ANDROID_API_LEVEL}" \
      "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done

  echo "Failed to install a compatible Android system image." >&2
  return 1
}

wait_for_boot() {
  local deadline boot_completed boot_anim
  deadline=$((SECONDS + ANDROID_BOOT_TIMEOUT_SECONDS))

  "$ADB_BIN" start-server >/dev/null
  "$ADB_BIN" -s "$ANDROID_SERIAL" wait-for-device

  while ((SECONDS < deadline)); do
    boot_completed="$("$ADB_BIN" -s "$ANDROID_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    boot_anim="$("$ADB_BIN" -s "$ANDROID_SERIAL" shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r')"

    if [[ "$boot_completed" == "1" && "$boot_anim" == "stopped" ]]; then
      return 0
    fi

    sleep 5
  done

  echo "Android emulator did not boot within ${ANDROID_BOOT_TIMEOUT_SECONDS}s." >&2
  return 1
}

wait_for_package_manager() {
  local deadline
  deadline=$((SECONDS + 120))

  while ((SECONDS < deadline)); do
    if "$ADB_BIN" -s "$ANDROID_SERIAL" shell pm path android >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  echo "Android package manager did not become ready in time." >&2
  return 1
}

cleanup() {
  "$ADB_BIN" -s "$ANDROID_SERIAL" emu kill >/dev/null 2>&1 || true
}
trap cleanup EXIT

SYSTEM_IMAGE_PACKAGE="$(install_system_image)"
rm -rf "$HOME/.android/avd/${ANDROID_EMULATOR_NAME}.avd" "$HOME/.android/avd/${ANDROID_EMULATOR_NAME}.ini"
echo "no" | "$AVDMANAGER" create avd \
  --force \
  --name "$ANDROID_EMULATOR_NAME" \
  --package "$SYSTEM_IMAGE_PACKAGE" \
  --device "$ANDROID_EMULATOR_DEVICE" >/dev/null

: >"$EMULATOR_LOG"
"$EMULATOR_BIN" \
  -avd "$ANDROID_EMULATOR_NAME" \
  -port "$ANDROID_EMULATOR_PORT" \
  -no-window \
  -gpu swiftshader_indirect \
  -no-snapshot \
  -noaudio \
  -no-boot-anim \
  -camera-back none \
  -camera-front none >"$EMULATOR_LOG" 2>&1 &

wait_for_boot
wait_for_package_manager

"$ADB_BIN" -s "$ANDROID_SERIAL" shell settings put global window_animation_scale 0 >/dev/null 2>&1 || true
"$ADB_BIN" -s "$ANDROID_SERIAL" shell settings put global transition_animation_scale 0 >/dev/null 2>&1 || true
"$ADB_BIN" -s "$ANDROID_SERIAL" shell settings put global animator_duration_scale 0 >/dev/null 2>&1 || true
"$ADB_BIN" -s "$ANDROID_SERIAL" shell wm dismiss-keyguard >/dev/null 2>&1 || true
"$ADB_BIN" -s "$ANDROID_SERIAL" shell input keyevent 82 >/dev/null 2>&1 || true

cd "$ANDROID_DIR"
./gradlew assembleDebug
"$ADB_BIN" -s "$ANDROID_SERIAL" install -r app/build/outputs/apk/debug/app-debug.apk

cd "$ROOT_DIR"
export ANDROID_SERIAL
bun run maestro:android
