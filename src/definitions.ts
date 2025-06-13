export interface CapacitorFFmpegPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
