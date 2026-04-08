# Capacitor FFmpeg Roadmap

Last updated: 2026-04-04
Status: active planning

## Why this file exists

This plugin is currently much smaller than FFmpeg itself:

- The TypeScript API exposes `getCapabilities()`, `reencodeVideo()`, `convertImage()`, a `progress` event, and `getPluginVersion()`.
- The Rust core currently focuses on one video re-encode path: decode video, encode H.264, and copy non-video streams.
- iOS has the only real native media implementation today.
- Android exposes `getPluginVersion()`, `getCapabilities()`, and `convertImage()`.
- Web is a stub.
- The test suite now covers basic wrapper contracts, but not media regressions yet.

This roadmap is the living source of truth for how we expand the plugin safely, how we test it, and how we keep its scope realistic.

## Can we use FFmpeg's own tests?

Short answer: yes, but selectively and indirectly.

FFmpeg's upstream regression system is FATE, documented at [ffmpeg.org/fate.html](https://ffmpeg.org/fate.html). It provides:

- a structured regression model via `make fate`
- a capability inventory via `make fate-list`
- an external sample corpus used to validate codecs, containers, filters, and tools

That is useful for this plugin, but it is not a drop-in test suite for Capacitor.

We should reuse FFmpeg's test work in these ways:

1. Use FATE as the capability map.
   Build a matrix from `make fate-list` and the upstream `tests/` tree to decide which FFmpeg behaviors matter for the plugin.
2. Reuse the testing style, not the whole suite.
   Port a curated subset of representative cases into Rust and platform-level regression tests.
3. Add plugin-specific assertions on top.
   FFmpeg upstream tests do not validate Capacitor concerns like file URL handling, progress events, cancellation, background execution, error mapping, or API parity between iOS and Android.

We should not:

- vendor the full FATE suite into this repository
- claim "full FFmpeg coverage"
- block normal PRs on a giant upstream-sized media matrix

The right goal is a well-documented, well-tested mobile subset of FFmpeg, with a path to expand over time.

## Current baseline

| Area      | Current state                                                      | Main gap                                                                                  |
| --------- | ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| JS API    | `getCapabilities`, `reencodeVideo`, `progress`, `getPluginVersion` | No probe, trim, remux, thumbnails, extract-audio, cancel, or cross-platform job execution |
| Rust core | One re-encode flow with progress callback                          | No unit tests, no fixture suite, no stable result model, no broader operation set         |
| iOS       | Real implementation exists                                         | Tied to a narrow workflow and limited test coverage                                       |
| Android   | Version method only                                                | No media engine, no API parity                                                            |
| Web       | Stub                                                               | No documented support story                                                               |
| Tests     | Basic web/iOS/Android contract tests                               | No media fixture coverage, no Rust regressions, and no end-to-end flows                   |
| Docs      | README documents support and roadmap links                         | No generated API docs yet for planned operations and no capability matrix by phase        |

## Scope model

We should not try to expose "all of FFmpeg" in one step. The plugin should grow in layers.

### Phase A: stable media core

- Media probe and metadata inspection
- Video re-encode presets
- Container remux when stream copy is possible
- Audio extraction
- Thumbnail generation
- Structured progress, errors, and cancellation

### Phase B: editing workflows

- Trim by start/end time
- Concatenate compatible inputs
- Stream selection and removal
- Subtitle passthrough and burn-in presets
- Watermark and simple filter presets

### Phase C: advanced workflows

- Validated custom filtergraph support
- HLS or DASH packaging
- Streaming inputs and outputs
- Hardware acceleration policy per platform
- Batch job orchestration

### Explicit non-goal for now

"Full FFmpeg surface area" is not a realistic near-term target for a Capacitor plugin. The practical target is: the most useful mobile-safe subset, with strong docs and tests.

## Test strategy

### 1. Upstream inventory

- Review FFmpeg FATE targets and group them by plugin-relevant capability: probe, format/container, video encode, audio handling, subtitles, filters, and seeking.
- Map each public plugin capability to at least one upstream-inspired regression case.

### 2. Curated fixtures

- Keep a small deterministic fixture set for the repository.
- Prefer synthetic media generated during tests when possible.
- Only import external media with clear provenance and acceptable licensing.
- Store expected metadata, not only golden binaries, when exact output bytes are not stable across platforms.

### 3. Rust regression tests

- Validate argument parsing and path normalization.
- Validate output container, codec, dimensions, stream layout, and duration tolerances.
- Validate error cases with broken or unsupported inputs.
- Avoid bit-for-bit assertions unless encoder determinism is guaranteed.

### 4. Platform wrapper tests

- iOS and Android must test argument validation, progress events, cancellation, overwrite policy, and native-to-JS error mapping.
- Use native tests for wrapper behavior and Rust/core tests for media behavior.

### 5. Example app smoke tests

- Add a small set of end-to-end flows in the example app.
- At minimum: probe -> transcode -> verify output metadata.

### 6. CI tiers

- PR tier: fast contract and regression tests on small fixtures.
- Scheduled tier: broader media compatibility suite using heavier fixtures.
- Release tier: platform verification plus example-app smoke flows.

## Roadmap

### M0. Foundation and cleanup

Status: completed

- Replace template XCTest and JUnit files with real tests or remove them until real tests exist.
- Standardize contributor scripts on Bun instead of `npm run`.
- Decide fixture storage strategy: in-repo, generated, or fetched in CI.
- Add a supported-platform matrix to the README.

Exit criteria:

- Local contributors can run the real test suites with Bun-based commands.
- The repo no longer suggests placeholder coverage.

### M1. Contract and feature inventory

Status: completed

- Define a stable TypeScript contract for jobs, results, progress, and failures.
- Write a feature matrix that lists planned capabilities and support by platform.
- Build an upstream-inspired test inventory from FATE categories and our own user needs.

Exit criteria:

- Every public method has a documented contract and a mapped test strategy.

### M2. iOS hardening

Status: in progress

- Stabilize the current re-encode path.
- Add structured progress and cancellation semantics.
- Clarify background execution behavior and platform minimums.
- Add real iOS native tests using media fixtures.

Exit criteria:

- iOS re-encode is stable enough to serve as the reference implementation for the plugin API.

### M3. Android media engine parity

Status: planned

- Choose the Android engine strategy: Rust via JNI or a separate native integration.
- Implement the same Phase A APIs as iOS.
- Add Android unit and instrumented tests around the wrapper and media results.

Exit criteria:

- Android reaches parity for the supported Phase A API surface.

### M4. Phase A feature completion

Status: planned

- Add `probeMedia`
- Add `generateThumbnail`
- Add `extractAudio`
- Add `remux`
- Add `trim`

Exit criteria:

- Phase A capabilities are implemented, documented, and covered by regression tests on iOS and Android.

### M5. Editing and filter presets

Status: planned

- Add stream selection
- Add concatenation for compatible media
- Add subtitle handling
- Add a small, validated set of filter presets

Exit criteria:

- Common app workflows no longer require raw FFmpeg command exposure.

### M6. Advanced workflows and reliability

Status: planned

- Evaluate custom filtergraph support
- Add heavier regression suites and performance baselines
- Add stress tests for long inputs and cancellation
- Add observability around failures and timing

Exit criteria:

- The plugin can support production workloads with predictable failure handling.

## Definition of done for every new capability

A feature is not done until all of the following are true:

- TypeScript definitions are updated
- iOS and Android support is implemented, or unsupported platforms are explicitly documented
- There is at least one regression test based on a fixture or generated sample
- Error behavior is specified
- Progress and cancellation behavior is specified when relevant
- README and generated API docs reflect the change
- This roadmap is updated

## How to update this roadmap

Update this file whenever one of these changes lands:

- public API surface changes
- milestone status changes
- a platform reaches parity or falls behind
- the test strategy changes
- a capability is dropped, deferred, or split into smaller phases

When updating:

1. Change the `Last updated` date.
2. Update the relevant milestone status.
3. Add one line to the roadmap journal below.

## Roadmap journal

- 2026-04-03: Created the first living roadmap based on the current plugin baseline and FFmpeg FATE evaluation.
- 2026-04-03: Completed M0 by switching package scripts to Bun, replacing template tests with contract tests, documenting fixture policy, and adding a README support matrix.
- 2026-04-03: Completed M1 with a typed JS contract, explicit unsupported-platform behavior, a published feature matrix, and an upstream-inspired test inventory; started M2 by moving iOS re-encode onto a queued wrapper contract without the previous hardcoded BackgroundTasks path.
- 2026-04-03: Added `getCapabilities()` so the current plugin scope is machine-readable on iOS, Android, and web, and aligned the docs around runtime feature gating.
- 2026-04-04: Replaced the placeholder example app with an FFmpeg capability playground, removed the broken Camera Preview path from the SwiftPM-based example app, added picker-backed video staging plus native iOS image conversion, and expanded Vitest coverage for the example app's runtime diagnostics and media flows.
