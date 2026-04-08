import type { createExampleApp } from './js/app';

declare global {
  interface Window {
    ffmpegExampleApp: ReturnType<typeof createExampleApp>;
  }
}

export {};
