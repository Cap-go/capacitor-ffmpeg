#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$(cd "$ROOT_DIR/.." && pwd)"

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ADB_BIN="${ADB_BIN:-$SDK_ROOT/platform-tools/adb}"
EMULATOR_BIN="${EMULATOR_BIN:-$SDK_ROOT/emulator/emulator}"
SDKMANAGER_BIN="${SDKMANAGER_BIN:-$SDK_ROOT/tools/bin/sdkmanager}"
AVDMANAGER_BIN="${AVDMANAGER_BIN:-$SDK_ROOT/tools/bin/avdmanager}"

ANDROID_API_LEVEL="${MAESTRO_ANDROID_API:-33}"
ANDROID_TAG="${MAESTRO_ANDROID_TAG:-google_apis}"

case "$(uname -m)" in
  arm64|aarch64)
    ANDROID_ABI="${MAESTRO_ANDROID_ABI:-arm64-v8a}"
    ;;
  *)
    ANDROID_ABI="${MAESTRO_ANDROID_ABI:-x86_64}"
    ;;
esac

SYSTEM_IMAGE_PACKAGE="system-images;android-${ANDROID_API_LEVEL};${ANDROID_TAG};${ANDROID_ABI}"
DEFAULT_AVD_NAME="maestro-pixel-6-api${ANDROID_API_LEVEL}-${ANDROID_ABI}"
PREFERRED_AVD_NAME="${MAESTRO_ANDROID_AVD:-}"
EMULATOR_LOG="$ROOT_DIR/build/maestro/android-emulator.log"

export PATH="$SDK_ROOT/platform-tools:$SDK_ROOT/emulator:$SDK_ROOT/tools/bin:$PATH"

require_executable() {
  local executable_path="$1"
  local label="$2"
  if [[ ! -x "$executable_path" ]]; then
    echo "$label not found at $executable_path" >&2
    exit 1
  fi
}

require_executable "$ADB_BIN" "adb"
require_executable "$EMULATOR_BIN" "emulator"

accept_android_licenses() {
  if [[ ! -x "$SDKMANAGER_BIN" ]]; then
    echo "sdkmanager is not available at $SDKMANAGER_BIN" >&2
    exit 1
  fi

  printf 'y\ny\ny\ny\ny\ny\n' | "$SDKMANAGER_BIN" --licenses >/dev/null || true
}

ensure_system_image() {
  local system_image_dir="$SDK_ROOT/system-images/android-${ANDROID_API_LEVEL}/${ANDROID_TAG}/${ANDROID_ABI}"
  if [[ -d "$system_image_dir" ]]; then
    return
  fi

  accept_android_licenses
  "$SDKMANAGER_BIN" "platform-tools" "emulator" "$SYSTEM_IMAGE_PACKAGE"
}

create_default_avd() {
  require_executable "$AVDMANAGER_BIN" "avdmanager"

  if "$EMULATOR_BIN" -list-avds | grep -qx "$DEFAULT_AVD_NAME"; then
    printf '%s\n' "$DEFAULT_AVD_NAME"
    return
  fi

  ensure_system_image
  printf 'no\n' | "$AVDMANAGER_BIN" create avd --force --name "$DEFAULT_AVD_NAME" --package "$SYSTEM_IMAGE_PACKAGE" --device "pixel_6" >/dev/null
  printf '%s\n' "$DEFAULT_AVD_NAME"
}

select_avd_name() {
  if [[ -n "$PREFERRED_AVD_NAME" ]]; then
    printf '%s\n' "$PREFERRED_AVD_NAME"
    return
  fi

  if "$EMULATOR_BIN" -list-avds | grep -qx 'Pixel_9a'; then
    printf 'Pixel_9a\n'
    return
  fi

  local first_existing_avd
  first_existing_avd="$("$EMULATOR_BIN" -list-avds | head -n 1 || true)"
  if [[ -n "$first_existing_avd" ]]; then
    printf '%s\n' "$first_existing_avd"
    return
  fi

  create_default_avd
}

wait_for_boot_completion() {
  local device_id="$1"

  "$ADB_BIN" -s "$device_id" wait-for-device
  for _ in $(seq 1 180); do
    local boot_completed
    boot_completed="$("$ADB_BIN" -s "$device_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "$boot_completed" == "1" ]]; then
      "$ADB_BIN" -s "$device_id" shell settings put global window_animation_scale 0 >/dev/null 2>&1 || true
      "$ADB_BIN" -s "$device_id" shell settings put global transition_animation_scale 0 >/dev/null 2>&1 || true
      "$ADB_BIN" -s "$device_id" shell settings put global animator_duration_scale 0 >/dev/null 2>&1 || true
      return
    fi
    sleep 2
  done

  echo "Android emulator $device_id did not finish booting." >&2
  exit 1
}

BOOTED_DEVICE_ID="$("$ADB_BIN" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
STARTED_EMULATOR=0
EMULATOR_PID=""

cleanup() {
  if [[ "$STARTED_EMULATOR" -eq 1 && -n "$BOOTED_DEVICE_ID" ]]; then
    "$ADB_BIN" -s "$BOOTED_DEVICE_ID" emu kill >/dev/null 2>&1 || true
  fi

  if [[ -n "$EMULATOR_PID" ]]; then
    kill "$EMULATOR_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

if [[ -z "$BOOTED_DEVICE_ID" ]]; then
  mkdir -p "$(dirname "$EMULATOR_LOG")"
  AVD_NAME="$(select_avd_name)"
  "$EMULATOR_BIN" "@$AVD_NAME" -no-window -gpu swiftshader_indirect -no-snapshot -noaudio -no-boot-anim >"$EMULATOR_LOG" 2>&1 &
  EMULATOR_PID=$!
  STARTED_EMULATOR=1

  for _ in $(seq 1 60); do
    BOOTED_DEVICE_ID="$("$ADB_BIN" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
    if [[ -n "$BOOTED_DEVICE_ID" ]]; then
      break
    fi
    sleep 2
  done

  if [[ -z "$BOOTED_DEVICE_ID" ]]; then
    echo "No Android emulator became available after launching AVD $AVD_NAME." >&2
    exit 1
  fi

  wait_for_boot_completion "$BOOTED_DEVICE_ID"
fi

if [[ "${MAESTRO_ANDROID_SKIP_PREBUILD:-0}" != "1" ]]; then
  (
    cd "$REPO_DIR"
    bun install
    bun run build
  )

  (
    cd "$ROOT_DIR"
    bun install
    bun run build
    bun run sync:android
    ./android/gradlew -p ./android assembleDebug
  )
fi

APK_PATH="$ROOT_DIR/android/app/build/outputs/apk/debug/app-debug.apk"
if [[ ! -f "$APK_PATH" ]]; then
  echo "Android debug APK not found at $APK_PATH" >&2
  exit 1
fi

"$ADB_BIN" -s "$BOOTED_DEVICE_ID" install -r "$APK_PATH" >/dev/null

if [[ "${MAESTRO_ANDROID_PREPARE_ONLY:-0}" == "1" ]]; then
  echo "Android emulator prepared and app installed on $BOOTED_DEVICE_ID."
  exit 0
fi

export ANDROID_SERIAL="$BOOTED_DEVICE_ID"
cd "$ROOT_DIR"
exec ./scripts/run-maestro-android.sh
