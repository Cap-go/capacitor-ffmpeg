# @capgo/capacitor-ffmpeg
 <a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin"> Missing a feature? We’ll build the plugin for you 💪</a></h2>
</div>
Exposes the FFmpeg API to Capacitor

## Documentation

The most complete doc is available here: https://capgo.app/docs/plugins/ffmpeg/

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
