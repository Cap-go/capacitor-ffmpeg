import type { Plugin, PluginListenerHandle } from '@capacitor/core';

export type FFmpegErrorCode =
  | 'UNIMPLEMENTED'
  | 'UNAVAILABLE'
  | 'INVALID_ARGUMENT'
  | 'PLUGIN_NOT_INITIALIZED'
  | 'TRANSCODE_FAILED';

export type FFmpegCapabilityStatus = 'available' | 'experimental' | 'unimplemented' | 'unavailable';
export type FFmpegJobState = 'queued' | 'running' | 'completed' | 'failed';
export type FFmpegProgressState = 'running' | 'completed' | 'failed';
export type ImageOutputFormat = 'webp' | 'jpeg' | 'png';

export interface FFmpegCapability {
  status: FFmpegCapabilityStatus;
  reason?: string;
}

export interface FFmpegCapabilitiesFeatures {
  getPluginVersion: FFmpegCapability;
  getCapabilities: FFmpegCapability;
  reencodeVideo: FFmpegCapability;
  convertImage: FFmpegCapability;
  progressEvents: FFmpegCapability;
  probeMedia: FFmpegCapability;
  generateThumbnail: FFmpegCapability;
  extractAudio: FFmpegCapability;
  remux: FFmpegCapability;
  trim: FFmpegCapability;
}

export interface FFmpegCapabilitiesResult {
  platform: string;
  features: FFmpegCapabilitiesFeatures;
}

export interface ReencodeVideoOptions {
  inputPath: string;
  outputPath: string;
  width: number;
  height: number;
  bitrate?: number;
}

export interface ConvertImageOptions {
  inputPath: string;
  outputPath: string;
  format: ImageOutputFormat;
  quality?: number;
}

export interface FFmpegAcceptedJob {
  jobId: string;
  status: 'queued';
}

export interface ConvertImageResult {
  outputPath: string;
  format: ImageOutputFormat;
}

export interface FFmpegProgressEvent {
  jobId: string;
  progress: number;
  state: FFmpegProgressState;
  message?: string;
  outputPath?: string;
  /**
   * Legacy alias kept for compatibility while callers migrate to `jobId`.
   */
  fileId?: string;
}

export interface PluginVersionResult {
  version: string;
}

export interface CapacitorFFmpegPlugin extends Plugin {
  /**
   * Return the machine-readable capability matrix for the current platform.
   */
  getCapabilities(): Promise<FFmpegCapabilitiesResult>;

  /**
   * Queue a video re-encode job.
   *
   * On iOS, the returned promise resolves when the native layer accepts the job.
   * Final success or failure is delivered through the `progress` listener.
   *
   * Android and web currently reject with `UNIMPLEMENTED`.
   */
  reencodeVideo(options: ReencodeVideoOptions): Promise<void | FFmpegAcceptedJob>;

  /**
   * Convert a still image into another format.
   *
   * iOS currently supports `jpeg` and `png`.
   * Android currently supports `webp`, `jpeg`, and `png`.
   * Web currently rejects with `UNIMPLEMENTED`.
   */
  convertImage(options: ConvertImageOptions): Promise<ConvertImageResult>;

  /**
   * Listen for media job progress.
   */
  addListener(eventName: 'progress', listenerFunc: (event: FFmpegProgressEvent) => void): Promise<PluginListenerHandle>;

  /**
   * Get the native Capacitor plugin version
   *
   * @returns {Promise<{ version: string }>} a promise with the native plugin version for this device
   * @throws An error if something went wrong
   */
  getPluginVersion(): Promise<PluginVersionResult>;
}
