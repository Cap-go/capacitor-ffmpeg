# Rust Library

This directory contains the native Rust core used by the iOS implementation of the Capacitor plugin.

## Current native scope

The exported C ABI currently exposes:

- `init_ffmpeg_plugin()`
- `deinit_ffmpeg_plugin(plugin)`
- `reencode_video(...)`
- `free_c_result(result)`

The only real media operation implemented today is `reencode_video`:

- decode video streams
- re-encode video to H.264 at the requested dimensions
- copy non-video streams where possible
- report progress through a callback provided by the Swift wrapper

This is not a general FFmpeg command bridge and it does not yet expose probe, trim, remux, thumbnail, or extract-audio operations.

## Building

```bash
cd rust
./build_ios.sh
```

To build with the local FFmpeg toolchain setup used by this repository:

```bash
cd rust
./build_ios.sh --with-ffmpeg
```

Expected outputs:

- `target/universal/release/libcapacitor_ffmpeg_rust_device.a`
- `target/universal/release/libcapacitor_ffmpeg_rust_sim.a`

## Requirements

- Rust toolchain with iOS targets
- Xcode with iOS SDKs
- The local `ffmpeg-sys` checkout expected by `Cargo.toml`

## Important limitation in this checkout

This repository currently patches `ffmpeg-sys-next` to a local `rust/ffmpeg-sys` path. If that directory is missing or incomplete, `cargo check` and native Rust verification will fail locally until the FFmpeg submodule or vendor directory is restored.
