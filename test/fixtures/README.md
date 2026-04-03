# Media Fixture Strategy

This directory holds the curated fixture set for plugin-level regression tests.

We are intentionally **not** vendoring the full FFmpeg FATE sample corpus here. The upstream FFmpeg project uses FATE to validate the full library and CLI surface, while this plugin only needs a mobile-oriented subset plus wrapper-specific assertions.

## Fixture policy

Use three buckets:

1. `generated/`
   Default choice for fast tests. Create tiny synthetic audio/video assets during the test run or in a lightweight setup step.
2. `samples/`
   Small checked-in files for stable cross-platform regressions that are hard to synthesize reliably.
3. `remote/`
   CI-only fixtures fetched from a manifest when a regression needs a larger real-world sample.

## Selection rules

- Prefer generated fixtures whenever possible.
- Keep checked-in samples small and license-clean.
- Do not store outputs that depend on bit-for-bit encoder determinism unless we pin the encoder path tightly enough to make that realistic.
- Assert metadata, stream layout, duration tolerances, and error handling before asserting exact bytes.

## First fixture set to add

- a short H.264 + AAC MP4 clip for the current `reencodeVideo()` path
- a WAV tone fixture for future audio extraction tests
- a small subtitle sample for passthrough and burn-in planning
- a deliberately broken media file for error-path coverage

## Relationship to FFmpeg upstream tests

When adding a new capability, first identify the closest upstream FATE category, then create the smallest plugin-level regression that covers:

- the media transformation itself
- JS/native argument handling
- progress and cancellation when relevant
- output validation at the plugin API boundary
