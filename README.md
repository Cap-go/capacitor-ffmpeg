# @capgo/capacitor-ffmpeg

<a href="https://capgo.app/">
  <img
    src="https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png"
    alt="Capgo - Instant updates for capacitor"
  />
</a>

<div align="center">
  <h2>
    <a href="https://capgo.app/?ref=plugin_ffmpeg"> ➡️ Get Instant updates for your App with Capgo</a>
  </h2>
  <h2>
    <a href="https://capgo.app/consulting/?ref=plugin_ffmpeg"> Missing a feature? We’ll build the plugin for you 💪</a>
  </h2>
</div>

This plugin exposes FFmpeg capabilities to Capacitor. The implementation is still early, and the supported feature set is intentionally smaller than upstream FFmpeg.

## Documentation

The most complete doc is available here: https://capgo.app/docs/plugins/ffmpeg/

Project roadmap: [ROADMAP.md](./ROADMAP.md)
Feature matrix: [FEATURE_MATRIX.md](./FEATURE_MATRIX.md)
Fixture strategy: [test/fixtures/README.md](./test/fixtures/README.md)
Test inventory: [test/TEST_INVENTORY.md](./test/TEST_INVENTORY.md)

## Compatibility

| Plugin version | Capacitor compatibility | Maintained |
| -------------- | ----------------------- | ---------- |
| v8.\*.\*       | v8.\*.\*                | ✅         |
| v7.\*.\*       | v7.\*.\*                | On demand  |
| v6.\*.\*       | v6.\*.\*                | ❌         |
| v5.\*.\*       | v5.\*.\*                | ❌         |

> **Note:** The major version of this plugin follows the major version of Capacitor. Use the version that matches your Capacitor installation (e.g., plugin v8 for Capacitor 8). Only the latest major version is actively maintained.

## Install

```bash
bun add @capgo/capacitor-ffmpeg
bunx cap sync
```

## Supported today

| Capability         | iOS             | Android | Web | Notes                                                                                                       |
| ------------------ | --------------- | ------- | --- | ----------------------------------------------------------------------------------------------------------- |
| `getCapabilities`  | ✅              | ✅      | ✅  | Returns the runtime capability matrix so apps can check what is actually usable on the current platform.    |
| `getPluginVersion` | ✅              | ✅      | ✅  | Returns a `{ version }` payload on every platform; use `getCapabilities().platform` for platform detection. |
| `reencodeVideo`    | ⚠️ Experimental | ❌      | ❌  | iOS accepts a queued job and reports lifecycle via `progress`; Android and web reject with `UNIMPLEMENTED`. |
| `convertImage`     | ✅              | ✅      | ❌  | iOS converts still images to `jpeg` or `png`; Android converts to `webp`, `jpeg`, or `png`; web rejects.    |
| `convertAudio`     | ✅              | ❌      | ❌  | iOS converts audio to `m4a`; Android and web reject with `UNIMPLEMENTED`.                                   |

## Platform status

| Platform | Status                        | Notes                                                                                                      |
| -------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------- |
| iOS      | Early implementation          | Current reference platform for media work.                                                                 |
| Android  | Partial native implementation | `convertImage` is native; the broader FFmpeg media engine and `convertAudio` still need to be implemented. |
| Web      | Stub only                     | Media operations are intentionally unsupported right now.                                                  |

## API

<docgen-index>

* [`getCapabilities()`](#getcapabilities)
* [`reencodeVideo(...)`](#reencodevideo)
* [`convertImage(...)`](#convertimage)
* [`convertAudio(...)`](#convertaudio)
* [`addListener('progress', ...)`](#addlistenerprogress-)
* [`getPluginVersion()`](#getpluginversion)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### getCapabilities()

```typescript
getCapabilities() => Promise<FFmpegCapabilitiesResult>
```

Return the machine-readable capability matrix for the current platform.

**Returns:** <code>Promise&lt;<a href="#ffmpegcapabilitiesresult">FFmpegCapabilitiesResult</a>&gt;</code>

--------------------


### reencodeVideo(...)

```typescript
reencodeVideo(options: ReencodeVideoOptions) => Promise<FFmpegAcceptedJob>
```

Queue a video re-encode job.

On iOS, the returned promise resolves when the native layer accepts the job.
Final success or failure is delivered through the `progress` listener.

Android and web currently reject with `UNIMPLEMENTED`.

| Param         | Type                                                                  |
| ------------- | --------------------------------------------------------------------- |
| **`options`** | <code><a href="#reencodevideooptions">ReencodeVideoOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#ffmpegacceptedjob">FFmpegAcceptedJob</a>&gt;</code>

--------------------


### convertImage(...)

```typescript
convertImage(options: ConvertImageOptions) => Promise<ConvertImageResult>
```

Convert a still image into another format.

iOS currently supports `jpeg` and `png`.
Android currently supports `webp`, `jpeg`, and `png`.
Web currently rejects with `UNIMPLEMENTED`.

| Param         | Type                                                                |
| ------------- | ------------------------------------------------------------------- |
| **`options`** | <code><a href="#convertimageoptions">ConvertImageOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#convertimageresult">ConvertImageResult</a>&gt;</code>

--------------------


### convertAudio(...)

```typescript
convertAudio(options: ConvertAudioOptions) => Promise<ConvertAudioResult>
```

Convert audio into another container or codec.

iOS currently supports `m4a`.
Android and web currently reject with `UNIMPLEMENTED`.

| Param         | Type                                                                |
| ------------- | ------------------------------------------------------------------- |
| **`options`** | <code><a href="#convertaudiooptions">ConvertAudioOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#convertaudioresult">ConvertAudioResult</a>&gt;</code>

--------------------


### addListener('progress', ...)

```typescript
addListener(eventName: 'progress', listenerFunc: (event: FFmpegProgressEvent) => void) => Promise<PluginListenerHandle>
```

Listen for media job progress.

| Param              | Type                                                                                    |
| ------------------ | --------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'progress'</code>                                                                 |
| **`listenerFunc`** | <code>(event: <a href="#ffmpegprogressevent">FFmpegProgressEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<PluginVersionResult>
```

Get the plugin package version reported by the current platform implementation.

**Returns:** <code>Promise&lt;<a href="#pluginversionresult">PluginVersionResult</a>&gt;</code>

--------------------


### Interfaces


#### FFmpegCapabilitiesResult

| Prop           | Type                                                                              |
| -------------- | --------------------------------------------------------------------------------- |
| **`platform`** | <code>string</code>                                                               |
| **`features`** | <code><a href="#ffmpegcapabilitiesfeatures">FFmpegCapabilitiesFeatures</a></code> |


#### FFmpegCapabilitiesFeatures

| Prop                    | Type                                                          |
| ----------------------- | ------------------------------------------------------------- |
| **`getPluginVersion`**  | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`getCapabilities`**   | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`reencodeVideo`**     | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`convertImage`**      | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`convertAudio`**      | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`progressEvents`**    | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`probeMedia`**        | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`generateThumbnail`** | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`extractAudio`**      | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`remux`**             | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |
| **`trim`**              | <code><a href="#ffmpegcapability">FFmpegCapability</a></code> |


#### FFmpegCapability

| Prop         | Type                                                                      |
| ------------ | ------------------------------------------------------------------------- |
| **`status`** | <code><a href="#ffmpegcapabilitystatus">FFmpegCapabilityStatus</a></code> |
| **`reason`** | <code>string</code>                                                       |


#### FFmpegAcceptedJob

| Prop         | Type                  |
| ------------ | --------------------- |
| **`jobId`**  | <code>string</code>   |
| **`status`** | <code>'queued'</code> |


#### ReencodeVideoOptions

| Prop             | Type                |
| ---------------- | ------------------- |
| **`inputPath`**  | <code>string</code> |
| **`outputPath`** | <code>string</code> |
| **`width`**      | <code>number</code> |
| **`height`**     | <code>number</code> |
| **`bitrate`**    | <code>number</code> |


#### ConvertImageResult

| Prop             | Type                                                            |
| ---------------- | --------------------------------------------------------------- |
| **`outputPath`** | <code>string</code>                                             |
| **`format`**     | <code><a href="#imageoutputformat">ImageOutputFormat</a></code> |


#### ConvertImageOptions

| Prop             | Type                                                            | Description                                                                                               |
| ---------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **`inputPath`**  | <code>string</code>                                             |                                                                                                           |
| **`outputPath`** | <code>string</code>                                             |                                                                                                           |
| **`format`**     | <code><a href="#imageoutputformat">ImageOutputFormat</a></code> |                                                                                                           |
| **`quality`**    | <code>number</code>                                             | Compression quality in the inclusive range `0.0..1.0`. Native platforms reject values outside that range. |


#### ConvertAudioResult

| Prop             | Type                                                            |
| ---------------- | --------------------------------------------------------------- |
| **`outputPath`** | <code>string</code>                                             |
| **`format`**     | <code><a href="#audiooutputformat">AudioOutputFormat</a></code> |


#### ConvertAudioOptions

| Prop             | Type                                                            |
| ---------------- | --------------------------------------------------------------- |
| **`inputPath`**  | <code>string</code>                                             |
| **`outputPath`** | <code>string</code>                                             |
| **`format`**     | <code><a href="#audiooutputformat">AudioOutputFormat</a></code> |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### FFmpegProgressEvent

| Prop             | Type                                                                | Description                                                                      |
| ---------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| **`jobId`**      | <code>string</code>                                                 |                                                                                  |
| **`progress`**   | <code>number</code>                                                 | Normalized progress as a floating-point value in the inclusive range `0.0..1.0`. |
| **`state`**      | <code><a href="#ffmpegprogressstate">FFmpegProgressState</a></code> |                                                                                  |
| **`message`**    | <code>string</code>                                                 |                                                                                  |
| **`outputPath`** | <code>string</code>                                                 |                                                                                  |
| **`fileId`**     | <code>string</code>                                                 | Legacy alias kept for compatibility while callers migrate to `jobId`.            |


#### PluginVersionResult

| Prop          | Type                |
| ------------- | ------------------- |
| **`version`** | <code>string</code> |


### Type Aliases


#### FFmpegCapabilityStatus

<code>'available' | 'experimental' | 'unimplemented' | 'unavailable'</code>


#### ImageOutputFormat

<code>'webp' | 'jpeg' | 'png'</code>


#### AudioOutputFormat

<code>'m4a'</code>


#### FFmpegProgressState

<code>'running' | 'completed' | 'failed'</code>

</docgen-api>
