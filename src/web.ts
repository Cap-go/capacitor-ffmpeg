import { WebPlugin } from '@capacitor/core';

import type { CapacitorFFmpegPlugin } from './definitions';

export class CapacitorFFmpegWeb extends WebPlugin implements CapacitorFFmpegPlugin {
  reencodeVideo(_options: { inputPath: string; outputPath: string; width: number; height: number }): Promise<void> {
    throw new Error('Method not implemented.');
  }

  async getPluginVersion(): Promise<{ version: string }> {
    return { version: 'web' };
  }
}
