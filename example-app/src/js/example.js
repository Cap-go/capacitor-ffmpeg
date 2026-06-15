import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { Capacitor } from '@capacitor/core';
import { CapacitorFFmpeg } from '@capgo/capacitor-ffmpeg';
import { Directory, Filesystem } from '@capacitor/filesystem';

import { createExampleApp } from './app';

async function mount() {
  const root = document.querySelector('#app');
  if (!root) {
    throw new Error('Missing #app root element.');
  }

  const app = createExampleApp({
    root,
    ffmpeg: CapacitorFFmpeg,
    filesystem: Filesystem,
    cacheDirectory: Directory.Cache,
  });

  await app.init();
  window.ffmpegExampleApp = app;
  if (Capacitor.isNativePlatform()) {
    await CapacitorUpdater.notifyAppReady().catch((error) => {
      console.error('Capgo notifyAppReady failed', error);
    });
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    mount().catch((error) => {
      console.error('[example-app] failed to initialize', error);
    });
  }, { once: true });
} else {
  mount().catch((error) => {
    console.error('[example-app] failed to initialize', error);
  });
}
