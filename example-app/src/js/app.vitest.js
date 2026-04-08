// @vitest-environment jsdom

import { beforeEach, describe, expect, it, vi } from 'vitest';

import { buildSuggestedOutputPath, createExampleApp } from './app';

function createCapabilities(platform, overrides = {}) {
  return {
    platform,
    features: {
      getPluginVersion: { status: 'available' },
      getCapabilities: { status: 'available' },
      reencodeVideo: {
        status: overrides.reencodeVideo ?? 'unimplemented',
        reason:
          overrides.reencodeVideo === 'experimental'
            ? 'Native pipeline is available on iOS.'
            : 'The media pipeline is currently only available on iOS.',
      },
      convertImage: {
        status: overrides.convertImage ?? 'unimplemented',
        reason:
          overrides.convertImage === 'available'
            ? 'Still-image conversion is available on iOS.'
            : 'Image conversion is currently only available on iOS and Android.',
      },
      progressEvents: {
        status: overrides.reencodeVideo === 'experimental' ? 'available' : 'unavailable',
        reason:
          overrides.reencodeVideo === 'experimental'
            ? 'Progress events stream from the native job.'
            : 'No media jobs are available on this platform today.',
      },
      probeMedia: { status: 'unimplemented', reason: 'probeMedia is not implemented yet.' },
      generateThumbnail: { status: 'unimplemented', reason: 'generateThumbnail is not implemented yet.' },
      extractAudio: { status: 'unimplemented', reason: 'extractAudio is not implemented yet.' },
      remux: { status: 'unimplemented', reason: 'remux is not implemented yet.' },
      trim: { status: 'unimplemented', reason: 'trim is not implemented yet.' },
    },
  };
}

function flushPromises() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function mountApp({ ffmpeg, filesystem, now = () => 1700000000000 } = {}) {
  document.body.innerHTML = '<div id="root"></div>';
  const root = document.querySelector('#root');

  return createExampleApp({
    root,
    ffmpeg,
    filesystem,
    cacheDirectory: 'CACHE',
    now,
    logger: {
      log: vi.fn(),
      error: vi.fn(),
    },
  });
}

function createFilesystemMock() {
  const files = new Map();

  return {
    files,
    writeFile: vi.fn().mockImplementation(async ({ path, data }) => {
      files.set(path, data);
      return { uri: `file:///sandbox/${path}` };
    }),
    getUri: vi.fn().mockImplementation(async ({ path }) => ({
      uri: `file:///sandbox/${path}`,
    })),
    readFile: vi.fn().mockImplementation(async ({ path }) => ({
      data: files.get(path) ?? '',
    })),
  };
}

describe('buildSuggestedOutputPath', () => {
  it('creates a sibling output path with a custom suffix and extension', () => {
    expect(buildSuggestedOutputPath('/tmp/demo.mov', 123)).toBe('/tmp/demo-reencoded-123.mp4');
    expect(buildSuggestedOutputPath('demo.mov', 456, 'converted', 'webp')).toBe('demo-converted-456.webp');
  });
});

describe('example app', () => {
  let progressListener;
  let ffmpeg;
  let filesystem;

  beforeEach(() => {
    progressListener = undefined;
    filesystem = createFilesystemMock();
    ffmpeg = {
      getPluginVersion: vi.fn().mockResolvedValue({ version: '1.2.3' }),
      getCapabilities: vi.fn().mockResolvedValue(createCapabilities('web')),
      addListener: vi.fn().mockImplementation(async (_event, callback) => {
        progressListener = callback;
        return { remove: vi.fn() };
      }),
      reencodeVideo: vi.fn().mockRejectedValue(new Error('reencodeVideo is currently only available on iOS.')),
      convertImage: vi.fn().mockRejectedValue(new Error('convertImage is currently only available on iOS and Android.')),
    };
  });

  it('loads version and capabilities on init', async () => {
    const capabilities = createCapabilities('web');
    ffmpeg.getCapabilities.mockResolvedValue(capabilities);
    const app = mountApp({ ffmpeg, filesystem });

    await app.init();

    expect(app.refs.platformValue.textContent).toBe('web');
    expect(app.refs.versionValue.textContent).toBe('1.2.3');
    expect(app.refs.capabilitiesGrid.children.length).toBe(Object.keys(capabilities.features).length);
    expect(app.refs.queueReencodeButton.disabled).toBe(true);
    expect(app.refs.convertImageButton.disabled).toBe(true);
    expect(ffmpeg.addListener).toHaveBeenCalledWith('progress', expect.any(Function));
  });

  it('runs runtime checks and confirms unsupported media contracts on web', async () => {
    const app = mountApp({ ffmpeg, filesystem });
    await app.init();

    await app.runChecks();

    const checksText = app.refs.checksList.textContent;
    expect(checksText).toContain('Plugin version endpoint');
    expect(checksText).toContain('Capability matrix endpoint');
    expect(checksText).toContain('Progress listener registration');
    expect(checksText).toContain('Unsupported re-encode contract');
    expect(checksText).toContain('Unsupported image conversion contract');
    expect(checksText).toContain('reencodeVideo is currently only available on iOS.');
    expect(checksText).toContain('convertImage is currently only available on iOS and Android.');
    expect(ffmpeg.reencodeVideo).toHaveBeenCalledTimes(1);
    expect(ffmpeg.convertImage).toHaveBeenCalledTimes(1);
  });

  it('stages a picked video and queues a native job', async () => {
    ffmpeg.getCapabilities.mockResolvedValue(
      createCapabilities('ios', {
        reencodeVideo: 'experimental',
        convertImage: 'available',
      })
    );
    ffmpeg.reencodeVideo.mockResolvedValue({ jobId: 'job-42', status: 'queued' });

    const app = mountApp({
      ffmpeg,
      filesystem,
      now: () => 1234567890,
    });

    await app.init();
    await app.handleVideoPicked(new File(['video-data'], 'recording.mov', { type: 'video/quicktime' }));

    expect(app.refs.selectedVideoLabel.textContent).toContain('recording.mov');
    expect(app.refs.selectedVideoOutputLabel.textContent).toBe('1234567890-recording-reencoded-1234567890.mp4');

    await app.queueReencode();

    expect(ffmpeg.reencodeVideo).toHaveBeenCalledWith({
      inputPath: 'file:///sandbox/ffmpeg-playground/imports/1234567890-recording.mov',
      outputPath: 'file:///sandbox/ffmpeg-playground/imports/1234567890-recording-reencoded-1234567890.mp4',
      width: 960,
      height: 540,
      bitrate: 2097152,
    });
    expect(app.refs.jobIdValue.textContent).toBe('job-42');

    progressListener({
      jobId: 'job-42',
      progress: 1,
      state: 'completed',
      message: 'Done',
      outputPath: 'file:///sandbox/output.mp4',
    });

    expect(app.refs.jobStateValue.textContent).toBe('completed');
    expect(app.refs.outputValue.textContent).toBe('file:///sandbox/output.mp4');
  });

  it('stages a picked image and converts it through the plugin', async () => {
    ffmpeg.getCapabilities.mockResolvedValue(
      createCapabilities('ios', {
        reencodeVideo: 'experimental',
        convertImage: 'available',
      })
    );
    ffmpeg.convertImage.mockResolvedValue({
      outputPath: 'file:///sandbox/ffmpeg-playground/imports/1234567890-photo-converted-1234567890.jpeg',
      format: 'jpeg',
    });

    const app = mountApp({
      ffmpeg,
      filesystem,
      now: () => 1234567890,
    });

    await app.init();
    await app.handleImagePicked(new File(['image-data'], 'photo.png', { type: 'image/png' }));

    expect(app.refs.selectedImageLabel.textContent).toContain('photo.png');
    expect(app.refs.selectedImageOutputLabel.textContent).toBe('1234567890-photo-converted-1234567890.jpeg');

    await app.convertImage();

    expect(ffmpeg.convertImage).toHaveBeenCalledWith({
      inputPath: 'file:///sandbox/ffmpeg-playground/imports/1234567890-photo.png',
      outputPath: 'file:///sandbox/ffmpeg-playground/imports/1234567890-photo-converted-1234567890.jpeg',
      format: 'jpeg',
      quality: 0.85,
    });
    expect(app.refs.convertedImageStatus.textContent).toContain('Converted photo.png to jpeg');
    expect(app.refs.convertedImagePreview.src).toContain('data:image/jpeg;base64,');
  });

  it('loads bundled demo media without using the native picker', async () => {
    ffmpeg.getCapabilities.mockResolvedValue(
      createCapabilities('android', {
        convertImage: 'available',
      })
    );

    const app = mountApp({
      ffmpeg,
      filesystem,
      now: () => 1234567890,
    });

    await app.init();
    await app.loadDemoImage();
    await app.loadDemoVideo();

    expect(app.refs.selectedImageLabel.textContent).toContain('sample-image.png');
    expect(app.refs.selectedVideoLabel.textContent).toContain('sample-video.mp4');
    expect(app.refs.selectedImageOutputLabel.textContent).toBe('1234567890-sample-image-converted-1234567890.webp');
    expect(app.refs.selectedVideoOutputLabel.textContent).toBe('1234567890-sample-video-reencoded-1234567890.mp4');
  });
});
