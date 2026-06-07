import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { Capacitor } from '@capacitor/core';
import { CapacitorFFmpeg } from '@capgo/capacitor-ffmpeg';
import { Directory, Filesystem } from '@capacitor/filesystem';

import { createExampleApp } from './app';

function mount() {
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

  app.init().catch((error) => {
    console.error('[example-app] failed to initialize', error);
  });

  window.ffmpegExampleApp = app;
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', mount, { once: true });
} else {
  mount();
}

if (Capacitor.isNativePlatform()) {
  CapacitorUpdater.notifyAppReady().catch((error) => {
    console.error('Capgo notifyAppReady failed', error);
  });
}
