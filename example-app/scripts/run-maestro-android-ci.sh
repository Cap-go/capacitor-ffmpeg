#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$(cd "$ROOT_DIR/.." && pwd)"

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ANDROID_SDK_HOME="${ANDROID_SDK_HOME:-$HOME/.android}"
if [[ "$ANDROID_SDK_HOME" == "$SDK_ROOT" ]]; then
  ANDROID_SDK_HOME="$HOME/.android"
fi
ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$ANDROID_SDK_HOME/avd}"
ANDROID_EMULATOR_HOME="${ANDROID_EMULATOR_HOME:-$ANDROID_SDK_HOME}"

export ANDROID_SDK_HOME ANDROID_AVD_HOME ANDROID_EMULATOR_HOME

mkdir -p "$ANDROID_SDK_HOME" "$ANDROID_AVD_HOME"

find_sdk_tool() {
  local tool="$1"
  local candidate

  for candidate in \
    "$SDK_ROOT/cmdline-tools/latest/bin/$tool" \
    "$SDK_ROOT/cmdline-tools"/*/bin/"$tool" \
    "$SDK_ROOT/tools/bin/$tool" \
    "$SDK_ROOT/emulator/$tool" \
    "$SDK_ROOT/platform-tools/$tool"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if candidate="$(command -v "$tool" 2>/dev/null)"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

ADB_BIN="${ADB_BIN:-$(find_sdk_tool adb)}"
EMULATOR_BIN="${EMULATOR_BIN:-}"
SDKMANAGER_BIN="${SDKMANAGER_BIN:-}"
AVDMANAGER_BIN="${AVDMANAGER_BIN:-}"

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
EXPLICIT_EMULATOR_PORT="${MAESTRO_ANDROID_PORT:-}"
EMULATOR_PORT="${EXPLICIT_EMULATOR_PORT:-5554}"
EMULATOR_BOOT_TIMEOUT_SECONDS="${MAESTRO_ANDROID_BOOT_TIMEOUT_SECONDS:-240}"
PACKAGE_MANAGER_TIMEOUT_SECONDS="${MAESTRO_ANDROID_PACKAGE_MANAGER_TIMEOUT_SECONDS:-120}"
EMULATOR_LOG="$ROOT_DIR/build/maestro/android-emulator.log"

export PATH="$(dirname "$ADB_BIN"):$PATH"

require_executable() {
  local executable_path="$1"
  local label="$2"
  if [[ ! -x "$executable_path" ]]; then
    echo "$label not found at $executable_path" >&2
    exit 1
  fi
}

require_executable "$ADB_BIN" "adb"

resolve_emulator_tooling() {
  EMULATOR_BIN="${EMULATOR_BIN:-$(find_sdk_tool emulator)}"
  SDKMANAGER_BIN="${SDKMANAGER_BIN:-$(find_sdk_tool sdkmanager)}"
  AVDMANAGER_BIN="${AVDMANAGER_BIN:-$(find_sdk_tool avdmanager)}"

  require_executable "$EMULATOR_BIN" "emulator"
  require_executable "$SDKMANAGER_BIN" "sdkmanager"
  require_executable "$AVDMANAGER_BIN" "avdmanager"

  export PATH="$(dirname "$ADB_BIN"):$(dirname "$EMULATOR_BIN"):$(dirname "$SDKMANAGER_BIN"):$(dirname "$AVDMANAGER_BIN"):$PATH"
}

accept_android_licenses() {
  resolve_emulator_tooling
  printf 'y\ny\ny\ny\ny\ny\n' | "$SDKMANAGER_BIN" --licenses >/dev/null || true
}

ensure_system_image() {
  local system_image_dir="$SDK_ROOT/system-images/android-${ANDROID_API_LEVEL}/${ANDROID_TAG}/${ANDROID_ABI}"
  if [[ -d "$system_image_dir" ]]; then
    return
  fi

  accept_android_licenses
  "$SDKMANAGER_BIN" --install "platform-tools" "emulator" "platforms;android-${ANDROID_API_LEVEL}" "$SYSTEM_IMAGE_PACKAGE" >/dev/null
}

avd_config_dir() {
  local avd_name="$1"
  printf '%s/%s.avd\n' "$ANDROID_AVD_HOME" "$avd_name"
}

avd_config_path() {
  local avd_name="$1"
  printf '%s/config.ini\n' "$(avd_config_dir "$avd_name")"
}

avd_ini_path() {
  local avd_name="$1"
  printf '%s/%s.ini\n' "$ANDROID_SDK_HOME/avd" "$avd_name"
}

avd_exists() {
  local avd_name="$1"
  resolve_emulator_tooling
  "$EMULATOR_BIN" -list-avds | grep -qxF "$avd_name"
}

avd_matches_requested_image() {
  local avd_name="$1"
  local config_path
  local image_sysdir
  local tag_id
  local abi_type

  config_path="$(avd_config_path "$avd_name")"
  if [[ ! -f "$config_path" ]]; then
    return 1
  fi

  image_sysdir="$(grep -m 1 '^image.sysdir.1=' "$config_path" | cut -d '=' -f 2- || true)"
  tag_id="$(grep -m 1 '^tag.id=' "$config_path" | cut -d '=' -f 2- || true)"
  abi_type="$(grep -m 1 '^abi.type=' "$config_path" | cut -d '=' -f 2- || true)"

  [[ "$image_sysdir" == *"android-${ANDROID_API_LEVEL}/"* ]] &&
    [[ "$tag_id" == "$ANDROID_TAG" ]] &&
    [[ "$abi_type" == "$ANDROID_ABI" ]]
}

delete_avd() {
  local avd_name="$1"
  rm -rf "$(avd_config_dir "$avd_name")" "$(avd_ini_path "$avd_name")"
}

create_default_avd() {
  local recreate="${1:-0}"

  resolve_emulator_tooling

  if [[ "$recreate" == "1" ]]; then
    delete_avd "$DEFAULT_AVD_NAME"
  fi

  if avd_exists "$DEFAULT_AVD_NAME" && avd_matches_requested_image "$DEFAULT_AVD_NAME"; then
    printf '%s\n' "$DEFAULT_AVD_NAME"
    return
  fi

  delete_avd "$DEFAULT_AVD_NAME"
  ensure_system_image
  printf 'no\n' | "$AVDMANAGER_BIN" create avd --force --name "$DEFAULT_AVD_NAME" --package "$SYSTEM_IMAGE_PACKAGE" --device "pixel_6" >/dev/null

  if ! avd_exists "$DEFAULT_AVD_NAME" || [[ ! -f "$(avd_config_path "$DEFAULT_AVD_NAME")" ]]; then
    echo "Failed to create Android AVD $DEFAULT_AVD_NAME." >&2
    exit 1
  fi

  printf '%s\n' "$DEFAULT_AVD_NAME"
}

select_avd_name() {
  local candidate

  resolve_emulator_tooling

  if [[ -n "$PREFERRED_AVD_NAME" ]]; then
    if ! avd_exists "$PREFERRED_AVD_NAME"; then
      echo "Requested Android AVD $PREFERRED_AVD_NAME does not exist." >&2
      exit 1
    fi

    printf '%s\n' "$PREFERRED_AVD_NAME"
    return
  fi

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    if avd_matches_requested_image "$candidate"; then
      printf '%s\n' "$candidate"
      return
    fi
  done < <("$EMULATOR_BIN" -list-avds || true)

  create_default_avd
}

wait_for_boot_completion() {
  local device_id="$1"
  local boot_deadline
  local package_deadline

  "$ADB_BIN" -s "$device_id" wait-for-device
  boot_deadline=$((SECONDS + EMULATOR_BOOT_TIMEOUT_SECONDS))

  while ((SECONDS < boot_deadline)); do
    local boot_completed
    local boot_animation
    boot_completed="$("$ADB_BIN" -s "$device_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    boot_animation="$("$ADB_BIN" -s "$device_id" shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r')"
    if [[ "$boot_completed" == "1" && "$boot_animation" == "stopped" ]]; then
      break
    fi
    sleep 2
  done

  if ((SECONDS >= boot_deadline)); then
    echo "Android emulator $device_id did not finish booting." >&2
    exit 1
  fi

  package_deadline=$((SECONDS + PACKAGE_MANAGER_TIMEOUT_SECONDS))
  while ((SECONDS < package_deadline)); do
    if "$ADB_BIN" -s "$device_id" shell pm path android >/dev/null 2>&1; then
      "$ADB_BIN" -s "$device_id" shell settings put global window_animation_scale 0 >/dev/null 2>&1 || true
      "$ADB_BIN" -s "$device_id" shell settings put global transition_animation_scale 0 >/dev/null 2>&1 || true
      "$ADB_BIN" -s "$device_id" shell settings put global animator_duration_scale 0 >/dev/null 2>&1 || true
      "$ADB_BIN" -s "$device_id" shell wm dismiss-keyguard >/dev/null 2>&1 || true
      "$ADB_BIN" -s "$device_id" shell input keyevent 82 >/dev/null 2>&1 || true
      return
    fi
    sleep 2
  done

  echo "Android package manager did not become ready on $device_id." >&2
  exit 1
}

booted_emulator_serials() {
  "$ADB_BIN" devices | awk 'NR > 1 && $1 ~ /^emulator-[0-9]+$/ && $2 == "device" { print $1 }'
}

first_booted_emulator() {
  booted_emulator_serials | head -n 1
}

booted_emulator_avd_name() {
  local device_id="$1"
  "$ADB_BIN" -s "$device_id" emu avd name 2>/dev/null | tr -d '\r' | awk 'NF && $0 != "OK" { print; exit }'
}

booted_emulator_for_avd() {
  local requested_avd_name="$1"
  local device_id
  local active_avd_name

  while IFS= read -r device_id; do
    [[ -n "$device_id" ]] || continue
    active_avd_name="$(booted_emulator_avd_name "$device_id" || true)"
    if [[ "$active_avd_name" == "$requested_avd_name" ]]; then
      printf '%s\n' "$device_id"
      return 0
    fi
  done < <(booted_emulator_serials)

  return 1
}

first_compatible_booted_emulator() {
  local device_id
  local active_avd_name

  while IFS= read -r device_id; do
    [[ -n "$device_id" ]] || continue
    active_avd_name="$(booted_emulator_avd_name "$device_id" || true)"
    if [[ -n "$active_avd_name" ]] && avd_matches_requested_image "$active_avd_name"; then
      printf '%s\n' "$device_id"
      return 0
    fi
  done < <(booted_emulator_serials)

  return 1
}

new_booted_emulator() {
  local existing_serials="$1"
  local device_id

  while IFS= read -r device_id; do
    [[ -n "$device_id" ]] || continue
    if ! grep -qxF "$device_id" <<<"$existing_serials"; then
      printf '%s\n' "$device_id"
      return 0
    fi
  done < <(booted_emulator_serials)

  return 1
}

expected_port_emulator_ready() {
  local device_id="$1"
  local requested_avd_name="$2"
  local existing_serials="$3"
  local active_avd_name

  if ! "$ADB_BIN" -s "$device_id" get-state >/dev/null 2>&1; then
    return 1
  fi

  if grep -qxF "$device_id" <<<"$existing_serials"; then
    active_avd_name="$(booted_emulator_avd_name "$device_id" || true)"
    [[ -n "$active_avd_name" && "$active_avd_name" == "$requested_avd_name" ]] || return 1
  fi

  return 0
}

SELECTED_AVD_NAME=""
if [[ -n "$PREFERRED_AVD_NAME" ]]; then
  SELECTED_AVD_NAME="$(select_avd_name)"
  BOOTED_DEVICE_ID="$(booted_emulator_for_avd "$SELECTED_AVD_NAME" || true)"
else
  BOOTED_DEVICE_ID="$(first_compatible_booted_emulator || true)"
fi

STARTED_EMULATOR=0
EMULATOR_PID=""
PRESERVE_STARTED_EMULATOR=0

stop_started_emulator() {
  if [[ "$STARTED_EMULATOR" -eq 1 && -n "$BOOTED_DEVICE_ID" ]]; then
    "$ADB_BIN" -s "$BOOTED_DEVICE_ID" emu kill >/dev/null 2>&1 || true
  fi

  if [[ -n "$EMULATOR_PID" ]]; then
    kill "$EMULATOR_PID" >/dev/null 2>&1 || true
    wait "$EMULATOR_PID" >/dev/null 2>&1 || true
  fi

  STARTED_EMULATOR=0
  EMULATOR_PID=""
  BOOTED_DEVICE_ID=""
}

cleanup() {
  if [[ "$PRESERVE_STARTED_EMULATOR" -eq 0 ]]; then
    stop_started_emulator
  fi
}

trap cleanup EXIT

launch_avd() {
  local avd_name="$1"
  local existing_serials
  local expected_device_id=""
  local launched_device_id=""
  local -a emulator_args

  resolve_emulator_tooling
  mkdir -p "$(dirname "$EMULATOR_LOG")"
  : >"$EMULATOR_LOG"

  existing_serials="$(booted_emulator_serials)"
  emulator_args=("@$avd_name" -no-window -gpu swiftshader_indirect -no-snapshot -noaudio -no-boot-anim -camera-back none -camera-front none)
  if [[ -n "$EXPLICIT_EMULATOR_PORT" || -z "$existing_serials" ]]; then
    expected_device_id="emulator-${EMULATOR_PORT}"
    emulator_args=("@$avd_name" -port "$EMULATOR_PORT" -no-window -gpu swiftshader_indirect -no-snapshot -noaudio -no-boot-anim -camera-back none -camera-front none)
  fi

  BOOTED_DEVICE_ID=""
  "$EMULATOR_BIN" "${emulator_args[@]}" >"$EMULATOR_LOG" 2>&1 &
  EMULATOR_PID=$!
  STARTED_EMULATOR=1

  for _ in $(seq 1 120); do
    if [[ -n "$expected_device_id" ]]; then
      if expected_port_emulator_ready "$expected_device_id" "$avd_name" "$existing_serials"; then
        BOOTED_DEVICE_ID="$expected_device_id"
        return 0
      fi
    else
      launched_device_id="$(new_booted_emulator "$existing_serials" || true)"
      if [[ -n "$launched_device_id" ]]; then
        BOOTED_DEVICE_ID="$launched_device_id"
        return 0
      fi
    fi

    if ! kill -0 "$EMULATOR_PID" >/dev/null 2>&1; then
      break
    fi

    sleep 2
  done

  echo "No Android emulator became available after launching AVD $avd_name." >&2
  cat "$EMULATOR_LOG" >&2 || true
  return 1
}

if [[ -z "$BOOTED_DEVICE_ID" ]]; then
  AVD_NAME="${SELECTED_AVD_NAME:-$(select_avd_name)}"
  if ! launch_avd "$AVD_NAME"; then
    stop_started_emulator

    if [[ -n "$PREFERRED_AVD_NAME" ]]; then
      exit 1
    fi

    AVD_NAME="$(create_default_avd 1)"
    if ! launch_avd "$AVD_NAME"; then
      exit 1
    fi
  fi
fi

wait_for_boot_completion "$BOOTED_DEVICE_ID"

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
  PRESERVE_STARTED_EMULATOR=1
  echo "Android emulator prepared and app installed on $BOOTED_DEVICE_ID."
  exit 0
fi

export ANDROID_SERIAL="$BOOTED_DEVICE_ID"
cd "$ROOT_DIR"
./scripts/run-maestro-android.sh
