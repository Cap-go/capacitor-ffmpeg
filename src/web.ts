import { WebPlugin } from '@capacitor/core';

import type {
  CapacitorFFmpegPlugin,
  FFmpegAcceptedJob,
  FFmpegCapabilitiesResult,
  ConvertImageOptions,
  ConvertImageResult,
  PluginVersionResult,
  ReencodeVideoOptions,
} from './definitions';
import { PLUGIN_VERSION } from './pluginVersion';

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
        convertImage: {
          status: 'unimplemented',
          reason: 'Image conversion is currently only available on iOS and Android.',
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

  async reencodeVideo(options: ReencodeVideoOptions): Promise<FFmpegAcceptedJob> {
    void options;
    throw this.unimplemented('reencodeVideo is currently only available on iOS.');
  }

  async convertImage(options: ConvertImageOptions): Promise<ConvertImageResult> {
    void options;
    throw this.unimplemented('convertImage is currently only available on iOS and Android.');
  }

  async getPluginVersion(): Promise<PluginVersionResult> {
    return { version: PLUGIN_VERSION };
  }
}
