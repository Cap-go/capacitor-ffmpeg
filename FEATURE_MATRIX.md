# Feature Matrix

Last updated: 2026-04-03

This file tracks the public plugin contract and the current platform support level for each capability.

## Current public contract

| Surface                  | Contract today                                                                                    | Notes                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| `getCapabilities()`      | Resolves the runtime capability matrix on iOS, Android, and web                                   | Use this to branch app behavior by supported feature set. |
| `getPluginVersion()`     | Resolves `{ version: string }` on iOS, Android, and web                                           | Web returns `"web"` as a platform marker.                 |
| `reencodeVideo(options)` | Resolves when the job is accepted by iOS and returns `{ jobId, status: "queued" }` when available | Android and web reject with `UNIMPLEMENTED`.              |
| `progress` listener      | Emits `{ jobId, progress, state, message?, outputPath? }`                                         | `fileId` is kept as a compatibility alias for `jobId`.    |

## Failure contract

Use these codes as the shared error vocabulary for JS consumers:

| Code                     | Meaning                                                      | Current producers                            |
| ------------------------ | ------------------------------------------------------------ | -------------------------------------------- |
| `UNIMPLEMENTED`          | The API is not implemented on the current platform           | Android `reencodeVideo`, web `reencodeVideo` |
| `UNAVAILABLE`            | The API exists but cannot be used in the current environment | Reserved for future capabilities             |
| `INVALID_ARGUMENT`       | Caller input failed local validation                         | iOS `reencodeVideo` validation               |
| `PLUGIN_NOT_INITIALIZED` | Native core could not be initialized                         | iOS native wrapper                           |
| `TRANSCODE_FAILED`       | The media pipeline failed after acceptance or during setup   | iOS native wrapper and Rust bridge           |

## Platform support

| Capability                          | iOS             | Android            | Web                | Test status                                                       |
| ----------------------------------- | --------------- | ------------------ | ------------------ | ----------------------------------------------------------------- |
| `getCapabilities`                   | ✅              | ✅                 | ✅                 | Covered by unit or contract tests on all platforms                |
| `getPluginVersion`                  | ✅              | ✅                 | ✅                 | Covered by unit or contract tests on all platforms                |
| `reencodeVideo` acceptance contract | ✅              | ❌ `UNIMPLEMENTED` | ❌ `UNIMPLEMENTED` | Covered for iOS helpers and web/Android unsupported behavior      |
| `reencodeVideo` media execution     | ⚠️ Experimental | ❌                 | ❌                 | Wrapper contract covered; media regression fixtures still pending |
| `progress` listener contract        | ✅              | ❌                 | ❌                 | Covered by iOS helper tests                                       |
| `probeMedia`                        | ❌ Planned      | ❌ Planned         | ❌ Planned         | Not started                                                       |
| `generateThumbnail`                 | ❌ Planned      | ❌ Planned         | ❌ Planned         | Not started                                                       |
| `extractAudio`                      | ❌ Planned      | ❌ Planned         | ❌ Planned         | Not started                                                       |
| `remux`                             | ❌ Planned      | ❌ Planned         | ❌ Planned         | Not started                                                       |
| `trim`                              | ❌ Planned      | ❌ Planned         | ❌ Planned         | Not started                                                       |

## Notes

- iOS is still the reference platform for media work.
- `getCapabilities()` is the machine-readable source of truth for app-side feature gating.
- Android and web should reject unsupported media APIs explicitly instead of failing implicitly.
- Background continuation is not part of the current contract. The plugin currently guarantees queued background execution, not long-running background entitlement handling.
