## FFmpeg example app

This example app is a feature playground for [`@capgo/capacitor-ffmpeg`](..). It does two jobs:

- It gives contributors a concrete UI for the plugin surface that exists today.
- It provides automated tests for the app-side contract, including the expected unsupported behavior on web and Android.

### What the app covers

- `getPluginVersion()` rendering
- `getCapabilities()` rendering
- `progress` listener registration and UI updates
- picker-backed `reencodeVideo()` queue flow on iOS
- picker-backed `convertImage()` flow on iOS and Android, including photo -> WebP conversion on Android
- Unsupported `reencodeVideo()` smoke checks on platforms that report no media pipeline
- Unsupported `convertImage()` smoke checks on platforms that report no native image conversion path

### Run the app

```bash
bun install
bun run start
```

### Run the example tests

```bash
bun run test
```

### Verify the example

```bash
bun run verify
```

### Run Maestro flows

```bash
bun run maestro:ios
bun run maestro:android
bun run maestro:android:ci
```

The Android script bootstraps Maestro's embedded driver APKs explicitly and starts the instrumentation runner before running the flows. The CLI still owns the ADB port-forward setup so local runs match CI without fighting Maestro's session setup. Install Maestro CLI first before running `bun run maestro:android`; the script expects the local CLI artifacts under `$HOME/.maestro`.

`bun run maestro:android:ci` is the full Android local/CI launcher. It:

- boots an existing local AVD when possible
- falls back to creating a supported Android 33 emulator if no AVD exists
- builds the plugin and example app, syncs Android, installs the debug APK, and then runs the Maestro flows

Useful overrides:

- `MAESTRO_ANDROID_AVD` to force a specific local AVD name
- `MAESTRO_ANDROID_SKIP_PREBUILD=1` to skip the build/sync/assemble phase
- `MAESTRO_ANDROID_PREPARE_ONLY=1` to stop after booting the emulator and installing the app

### Native sync

If you change dependencies or native config in this example, sync the platforms:

```bash
bunx cap sync ios
bunx cap sync android
```

### Platform notes

- `web`: capability inspection, progress-listener registration, and unsupported-path smoke checks
- `android`: capability inspection, native image conversion, and unsupported video re-encode smoke checks
- `ios`: capability inspection, photo/video pickers, native image conversion, and native FFmpeg re-encode with progress events
