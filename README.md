# @capgo/capacitor-ffmpeg
 <a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_ffmpeg"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_ffmpeg"> Missing a feature? We’ll build the plugin for you 💪</a></h2>
</div>
WIP Exposes the FFmpeg API to Capacitor
We currently looking for the best way to make this work

## Documentation

The most complete doc is available here: https://capgo.app/docs/plugins/ffmpeg/

## Compatibility

| Plugin version | Capacitor compatibility | Maintained |
| -------------- | ----------------------- | ---------- |
| v8.\*.\*       | v8.\*.\*                | ✅          |
| v7.\*.\*       | v7.\*.\*                | On demand   |
| v6.\*.\*       | v6.\*.\*                | ❌          |
| v5.\*.\*       | v5.\*.\*                | ❌          |

> **Note:** The major version of this plugin follows the major version of Capacitor. Use the version that matches your Capacitor installation (e.g., plugin v8 for Capacitor 8). Only the latest major version is actively maintained.

## Install

```bash
npm install @capgo/capacitor-ffmpeg
npx cap sync
```

## API

<docgen-index>

* [`reencodeVideo(...)`](#reencodevideo)
* [`getPluginVersion()`](#getpluginversion)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### reencodeVideo(...)

```typescript
reencodeVideo(options: { inputPath: string; outputPath: string; width: number; height: number; bitrate?: number; }) => Promise<void>
```

| Param         | Type                                                                                                     |
| ------------- | -------------------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ inputPath: string; outputPath: string; width: number; height: number; bitrate?: number; }</code> |

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<{ version: string; }>
```

Get the native Capacitor plugin version

**Returns:** <code>Promise&lt;{ version: string; }&gt;</code>

--------------------

</docgen-api>
