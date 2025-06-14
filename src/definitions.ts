export interface CapacitorFFmpegPlugin {
  reencodeVideo(options: {
    inputPath: string;
    outputPath: string;
    width: number;
    height: number;
    bitrate?: number;
  }): Promise<void>;
}
