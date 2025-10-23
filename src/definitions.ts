export interface CapacitorFFmpegPlugin {
  reencodeVideo(options: {
    inputPath: string;
    outputPath: string;
    width: number;
    height: number;
    bitrate?: number;
  }): Promise<void>;

  /**
   * Get the native Capacitor plugin version
   *
   * @returns {Promise<{ id: string }>} an Promise with version for this device
   * @throws An error if the something went wrong
   */
  getPluginVersion(): Promise<{ version: string }>;
}
