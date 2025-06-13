# Rust Library for iOS

This directory contains a Rust library that exposes C functions for use in the iOS Capacitor plugin.

## Functions

- `add_two_numbers(a: i32, b: i32) -> i32` - Adds two numbers and returns the result

## Building

To build the library for iOS **without** FFmpeg support (recommended for initial setup):

```bash
cd rust
./build_ios.sh
```

To build the library for iOS **with** FFmpeg support (requires FFmpeg setup):

```bash
cd rust
./build_ios.sh --with-ffmpeg
```

This will create:
- `target/universal/release/libcapacitor_ffmpeg_rust_device.a` - For iOS devices  
- `target/universal/release/libcapacitor_ffmpeg_rust_sim.a` - For iOS simulator

## FFmpeg Support

The FFmpeg dependency is optional and controlled by a feature flag:
- **Without FFmpeg**: Basic functionality (like `add_two_numbers`) works immediately
- **With FFmpeg**: Full FFmpeg functionality, but requires proper cross-compilation setup

When built without FFmpeg, `initializeFFmpeg()` will return `-2` (not available).

## Usage in Swift

The function is available in Swift as:

```swift
let result = implementation.addTwoNumbers(10, 20)
```

## Usage from JavaScript

Once the plugin is built, you can call it from JavaScript:

```javascript
import { CapacitorFFmpeg } from 'your-plugin-name';

const result = await CapacitorFFmpeg.addTwoNumbers({ a: 10, b: 20 });
console.log(result.result); // 30
```

## Requirements

- Rust toolchain with iOS targets
- Xcode with iOS SDK
- The library must be built before building the iOS project 