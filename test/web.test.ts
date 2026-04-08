import { ExceptionCode } from '@capacitor/core';
import { describe, expect, it } from 'bun:test';

import { CapacitorFFmpegWeb } from '../src/web';

describe('CapacitorFFmpegWeb', () => {
  it('returns the web plugin version marker', async () => {
    const plugin = new CapacitorFFmpegWeb();

    await expect(plugin.getPluginVersion()).resolves.toEqual({ version: 'web' });
  });

  it('describes the current web capability matrix', async () => {
    const plugin = new CapacitorFFmpegWeb();

    await expect(plugin.getCapabilities()).resolves.toMatchObject({
      platform: 'web',
      features: {
        getCapabilities: { status: 'available' },
        reencodeVideo: { status: 'unimplemented' },
        convertImage: { status: 'unimplemented' },
      },
    });
  });

  it('keeps media operations explicitly unsupported on web', async () => {
    const plugin = new CapacitorFFmpegWeb();

    await expect(
      plugin.reencodeVideo({
        inputPath: 'file:///input.mp4',
        outputPath: 'file:///output.mp4',
        width: 1280,
        height: 720,
      }),
    ).rejects.toMatchObject({
      code: ExceptionCode.Unimplemented,
      message: 'reencodeVideo is currently only available on iOS.',
    });

    await expect(
      plugin.convertImage({
        inputPath: 'file:///input.png',
        outputPath: 'file:///output.webp',
        format: 'webp',
      }),
    ).rejects.toMatchObject({
      code: ExceptionCode.Unimplemented,
      message: 'convertImage is currently only available on iOS and Android.',
    });
  });
});
