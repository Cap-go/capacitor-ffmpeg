import { WebPlugin } from '@capacitor/core';

import type { CapacitorFFmpegPlugin } from './definitions';

export class CapacitorFFmpegWeb extends WebPlugin implements CapacitorFFmpegPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
