import { WebPlugin } from '@capacitor/core';

import type {
  CapacitorFFmpegPlugin,
  FFmpegAcceptedJob,
  FFmpegCapabilitiesResult,
  PluginVersionResult,
  ReencodeVideoOptions,
} from './definitions';

export class CapacitorFFmpegWeb extends WebPlugin implements CapacitorFFmpegPlugin {
  async getCapabilities(): Promise<FFmpegCapabilitiesResult> {
    return {
      platform: 'web',
      features: {
        getPluginVersion: { status: 'available' },
        getCapabilities: { status: 'available' },
        reencodeVideo: {
          status: 'unimplemented',
          reason: 'The media pipeline is currently only available on iOS.',
        },
        progressEvents: {
          status: 'unavailable',
          reason: 'No media jobs are available on web today.',
        },
        probeMedia: {
          status: 'unimplemented',
          reason: 'probeMedia is not implemented on web.',
        },
        generateThumbnail: {
          status: 'unimplemented',
          reason: 'generateThumbnail is not implemented on web.',
        },
        extractAudio: {
          status: 'unimplemented',
          reason: 'extractAudio is not implemented on web.',
        },
        remux: {
          status: 'unimplemented',
          reason: 'remux is not implemented on web.',
        },
        trim: {
          status: 'unimplemented',
          reason: 'trim is not implemented on web.',
        },
      },
    };
  }

  async reencodeVideo(options: ReencodeVideoOptions): Promise<void | FFmpegAcceptedJob> {
    void options;
    throw this.unimplemented('reencodeVideo is currently only available on iOS.');
  }

  async getPluginVersion(): Promise<PluginVersionResult> {
    return { version: 'web' };
  }
}
