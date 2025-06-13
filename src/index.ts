import { registerPlugin } from '@capacitor/core';

import type { CapacitorFFmpegPlugin } from './definitions';

const CapacitorFFmpeg = registerPlugin<CapacitorFFmpegPlugin>('CapacitorFFmpeg', {
  web: () => import('./web').then((m) => new m.CapacitorFFmpegWeb()),
});

export * from './definitions';
export { CapacitorFFmpeg };
