# Test Inventory

Last updated: 2026-04-13

This file maps the public plugin contract to the tests that exist now and the next regression coverage we still need.

## Current inventory

| Surface                              | Upstream-inspired category             | Current coverage                                                                                                  | Next missing coverage                                                                      |
| ------------------------------------ | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `getCapabilities`                    | Plugin-only scope introspection        | Web contract test, Android unit test, iOS helper test                                                             | Add JS integration test against the registered plugin surface                              |
| `getPluginVersion`                   | Wrapper contract, no FFmpeg equivalent | Web contract test, Android unit test                                                                              | iOS plugin wrapper test                                                                    |
| `reencodeVideo` unsupported behavior | Plugin-only contract                   | Web contract test, Android unit test helper                                                                       | None for current scope                                                                     |
| `convertImage` unsupported behavior  | Plugin-only contract                   | Web contract test                                                                                                 | None for current scope                                                                     |
| `convertImage` native execution      | Still-image transcode                  | Android unit test helper, iOS native test for fixture generation and output write, Maestro Android+iOS flows      | Add wrapper-level test with `CAPPluginCall` and output file metadata validation            |
| `convertAudio` unsupported behavior  | Plugin-only contract                   | Web contract test, Android unit test helper                                                                       | None for current scope                                                                     |
| `convertAudio` native execution      | Audio transcode                        | iOS native tests for format validation, successful export wrapper behavior, and failed export cleanup             | Add end-to-end regression against a real exported file when simulator export is stable     |
| `reencodeVideo` acceptance result    | Plugin job contract                    | iOS helper tests for queued job payload                                                                           | iOS plugin wrapper test                                                                    |
| `progress` event payload             | Plugin job/progress contract           | iOS helper tests                                                                                                  | End-to-end event assertion during a real encode                                            |
| Example app runtime harness          | App-level contract smoke               | Vitest example-app checks plus Maestro iOS/Android flows for runtime checks, image conversion, and iOS video flow | Add native device smoke flow: pick arbitrary gallery media -> transcode -> verify metadata |
| `reencodeVideo` media pipeline       | FATE-adjacent video encode + mux path  | Not yet covered by fixture tests                                                                                  | Add generated MP4 fixture, assert output metadata and duration tolerance                   |
| Invalid media input handling         | FATE-style negative regression         | Not yet covered                                                                                                   | Add broken fixture and assert `TRANSCODE_FAILED` or structured failure progress event      |

## FATE-inspired mapping

We are not importing upstream FATE directly. We are using it as a taxonomy:

| Planned capability  | Closest upstream area         | Plugin-level assertion style                                                                |
| ------------------- | ----------------------------- | ------------------------------------------------------------------------------------------- |
| `probeMedia`        | Demuxer / container probe     | Assert metadata JSON, stream counts, codecs, duration tolerance                             |
| `reencodeVideo`     | Decode + encode + mux         | Assert output container, video dimensions, codec family, and non-video stream copy behavior |
| `extractAudio`      | Demux + audio mux             | Assert audio-only output stream layout and duration tolerance                               |
| `generateThumbnail` | Decode + seek + image encode  | Assert image dimensions, timestamp tolerance, and failure behavior on invalid seeks         |
| `remux`             | Stream copy / container remap | Assert codec preservation and no unintended transcoding                                     |
| `trim`              | Seek + mux                    | Assert start offset, duration tolerance, and keyframe behavior                              |

## CI tiers

| Tier      | Purpose                                                                                       | Current status |
| --------- | --------------------------------------------------------------------------------------------- | -------------- |
| PR        | Contract tests, type/build verification, wrapper regressions, Maestro example-app smoke flows | Active         |
| Scheduled | Heavier media fixtures and broader codec/container matrix                                     | Planned        |
| Release   | Platform verification plus example-app smoke paths                                            | Planned        |

## Immediate next media tests

1. Generate a tiny MP4 input fixture for the current iOS re-encode flow.
2. Add a real exported-audio regression once simulator-side `AVAssetExportSession` output is stable in CI.
3. Add a broken-input fixture and assert structured failure reporting.
