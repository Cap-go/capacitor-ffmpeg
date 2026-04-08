import sampleImageDataUrl from '../assets/sample-image.png?inline';
import sampleVideoDataUrl from '../assets/sample-video.mp4?inline';

const FEATURE_ORDER = [
  'getPluginVersion',
  'getCapabilities',
  'reencodeVideo',
  'convertImage',
  'progressEvents',
  'probeMedia',
  'generateThumbnail',
  'extractAudio',
  'remux',
  'trim',
];

const FEATURE_LABELS = {
  getPluginVersion: 'Plugin version',
  getCapabilities: 'Capability matrix',
  reencodeVideo: 'Re-encode video',
  convertImage: 'Convert image',
  progressEvents: 'Progress events',
  probeMedia: 'Probe media',
  generateThumbnail: 'Generate thumbnail',
  extractAudio: 'Extract audio',
  remux: 'Remux container',
  trim: 'Trim clip',
};

const STATUS_LABELS = {
  available: 'Available',
  experimental: 'Experimental',
  unimplemented: 'Unimplemented',
  unavailable: 'Unavailable',
  passed: 'Passed',
  failed: 'Failed',
  skipped: 'Skipped',
};

const IMAGE_MIME_TYPES = {
  webp: 'image/webp',
  jpeg: 'image/jpeg',
  png: 'image/png',
};

const DEMO_MEDIA = {
  image: {
    dataUrl: sampleImageDataUrl,
    name: 'sample-image.png',
    mimeType: 'image/png',
  },
  video: {
    dataUrl: sampleVideoDataUrl,
    name: 'sample-video.mp4',
    mimeType: 'video/mp4',
  },
};

function formatFeatureLabel(featureName) {
  return FEATURE_LABELS[featureName] ?? featureName;
}

function formatStatusLabel(status) {
  return STATUS_LABELS[status] ?? status;
}

function createInitialMarkup() {
  return `
    <main class="shell">
      <header class="hero panel">
        <div class="hero-copy">
          <p class="eyebrow">Capgo example app</p>
          <h1>FFmpeg capability playground</h1>
          <p class="hero-text">
            Use real pickers instead of hand-written paths, check the runtime contract, and exercise the media
            features that actually exist on this device.
          </p>
        </div>
        <div class="hero-actions">
          <button id="refreshRuntimeButton" class="button button-primary" type="button">Refresh runtime</button>
          <button id="runChecksButton" class="button button-secondary" type="button">Run runtime checks</button>
          <button id="showImageWorkflowButton" class="button workflow-toggle" type="button" aria-pressed="true">
            Show image workflow
          </button>
          <button id="showVideoWorkflowButton" class="button workflow-toggle" type="button" aria-pressed="false">
            Show video workflow
          </button>
        </div>
      </header>

      <section id="imagePanels" class="grid-two workflow-panel-group">
        <article id="imageWorkflowSection" class="panel">
          <div class="section-head">
            <div>
              <p class="eyebrow">Still image flow</p>
              <h2>Convert image format</h2>
            </div>
          </div>
          <input id="imagePickerInput" type="file" accept="image/*" hidden />
          <div class="picker-stack">
            <div class="picker-card">
              <div>
                <strong>Source image</strong>
                <p id="selectedImageLabel" class="muted" data-testid="selected-image-label">
                  No image selected yet.
                </p>
              </div>
              <div class="button-row">
                <button id="pickImageButton" class="button button-primary" type="button">Choose image</button>
                <button id="loadDemoImageButton" class="button button-secondary" type="button">Load demo image</button>
              </div>
            </div>
          </div>
          <div class="button-row">
            <button id="convertImageButton" class="button button-primary" type="button">Convert image</button>
          </div>
          <p id="convertedImageStatus" class="muted" data-testid="converted-image-status">
            No converted image yet.
          </p>
          <details class="advanced-details">
            <summary>Advanced image options</summary>
            <div class="advanced-content">
              <div class="field-row field-row-compact">
                <label class="field">
                  <span>Format</span>
                  <select id="imageFormatField">
                    <option value="webp">WebP</option>
                    <option value="jpeg">JPEG</option>
                    <option value="png">PNG</option>
                  </select>
                </label>
                <label class="field">
                  <span>Quality</span>
                  <input id="imageQualityField" type="number" min="0" max="1" step="0.05" value="0.85" />
                </label>
              </div>
              <p class="muted">
                Output file:
                <span id="selectedImageOutputLabel" data-testid="selected-image-output-label">
                  Pick an image to generate an output path.
                </span>
              </p>
            </div>
          </details>
          <p id="imageHint" class="muted">
            On iOS this uses the native plugin to write a converted file into the app sandbox.
          </p>
        </article>

        <article class="panel">
          <div class="section-head">
            <div>
              <p class="eyebrow">Preview</p>
              <h2>Selected vs converted</h2>
            </div>
          </div>
          <div class="preview-grid">
            <figure class="preview-card">
              <figcaption>Selected image</figcaption>
              <img id="selectedImagePreview" alt="Selected input preview" />
            </figure>
            <figure class="preview-card">
              <figcaption>Converted image</figcaption>
              <img id="convertedImagePreview" alt="Converted output preview" />
            </figure>
          </div>
        </article>
      </section>

      <section id="videoPanels" class="grid-two workflow-panel-group" hidden>
        <article id="videoWorkflowSection" class="panel">
          <div class="section-head">
            <div>
              <p class="eyebrow">Manual workflow</p>
              <h2>Video re-encode</h2>
            </div>
          </div>
          <input id="videoPickerInput" type="file" accept="video/*" hidden />
          <div class="picker-stack">
            <div class="picker-card">
              <div>
                <strong>Source video</strong>
                <p id="selectedVideoLabel" class="muted" data-testid="selected-video-label">
                  No video selected yet.
                </p>
              </div>
              <div class="button-row">
                <button id="pickVideoButton" class="button button-primary" type="button">Choose video</button>
                <button id="loadDemoVideoButton" class="button button-secondary" type="button">Load demo video</button>
              </div>
            </div>
          </div>
          <div class="button-row">
            <button id="queueReencodeButton" class="button button-primary" type="button">Queue re-encode</button>
            <button id="unsupportedSmokeButton" class="button button-secondary" type="button">
              Verify unsupported path
            </button>
          </div>
          <details class="advanced-details">
            <summary>Advanced video options</summary>
            <div class="advanced-content">
              <div class="field-row">
                <label class="field">
                  <span>Width</span>
                  <input id="widthField" name="width" type="number" min="1" step="1" value="960" />
                </label>
                <label class="field">
                  <span>Height</span>
                  <input id="heightField" name="height" type="number" min="1" step="1" value="540" />
                </label>
                <label class="field">
                  <span>Bitrate</span>
                  <input id="bitrateField" name="bitrate" type="number" min="1" step="1" value="2097152" />
                </label>
              </div>
              <p class="muted">
                Output file:
                <span id="selectedVideoOutputLabel" data-testid="selected-video-output-label">
                  Output path will be generated after you pick a source video.
                </span>
              </p>
            </div>
          </details>
          <p id="manualHint" class="muted">
            Pick a video from the device and the app will stage it inside its sandbox before calling the plugin.
          </p>
        </article>

        <article class="panel">
          <div class="section-head">
            <div>
              <p class="eyebrow">Event stream</p>
              <h2>Progress</h2>
            </div>
          </div>
          <dl class="job-grid">
            <div>
              <dt>Job</dt>
              <dd id="jobIdValue" data-testid="job-id-value">No job yet</dd>
            </div>
            <div>
              <dt>State</dt>
              <dd id="jobStateValue" data-testid="job-state-value">Idle</dd>
            </div>
            <div>
              <dt>Output</dt>
              <dd id="outputValue" data-testid="output-value">No output yet</dd>
            </div>
          </dl>
          <div class="progress-shell" aria-label="Progress">
            <div id="progressFill" class="progress-fill" data-testid="progress-fill"></div>
          </div>
          <p id="progressLabel" class="progress-label" data-testid="progress-label">Waiting for events</p>
        </article>
      </section>

      <section class="summary-grid">
        <article class="stat-card panel">
          <span class="stat-label">Platform</span>
          <strong id="platformValue" data-testid="platform-value">Loading…</strong>
        </article>
        <article class="stat-card panel">
          <span class="stat-label">Plugin version</span>
          <strong id="versionValue" data-testid="version-value">Loading…</strong>
        </article>
        <article class="stat-card panel">
          <span class="stat-label">Media pipeline</span>
          <strong id="pipelineValue" data-testid="pipeline-value">Checking…</strong>
        </article>
      </section>

      <section class="grid-two">
        <article class="panel">
          <div class="section-head">
            <div>
              <p class="eyebrow">Runtime surface</p>
              <h2>Capabilities</h2>
            </div>
          </div>
          <div id="capabilitiesGrid" class="capability-grid" data-testid="capabilities-grid"></div>
        </article>

        <article class="panel">
          <div class="section-head">
            <div>
              <p class="eyebrow">Diagnostics</p>
              <h2>Runtime checks</h2>
            </div>
          </div>
          <ul id="checksList" class="check-list" data-testid="checks-list">
            <li class="check-item check-item-empty">Checks have not been run yet.</li>
          </ul>
        </article>
      </section>

      <section class="grid-two">
        <article class="panel">
          <div class="section-head">
            <div>
              <p class="eyebrow">Workflow note</p>
              <h2>What this app is proving</h2>
            </div>
          </div>
          <p class="muted">
            The image workflow verifies file picking plus real conversion into a new image format. The video workflow
            verifies the native FFmpeg-backed re-encode job contract and progress stream.
          </p>
        </article>
      </section>

      <section class="panel">
        <div class="section-head">
          <div>
            <p class="eyebrow">Trace</p>
            <h2>Event log</h2>
          </div>
        </div>
        <ol id="eventLog" class="log-list" data-testid="event-log"></ol>
      </section>
    </main>
  `;
}

function clampProgress(progress) {
  return Math.min(Math.max(progress ?? 0, 0), 1);
}

function normalizeImageFormat(format) {
  return format === 'jpg' ? 'jpeg' : String(format ?? '').toLowerCase();
}

function sanitizeFilenameSegment(value) {
  return String(value || 'file')
    .trim()
    .replace(/[^a-zA-Z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'file';
}

function buildRelativeSandboxPath(kind, fileName, stamp = Date.now()) {
  return `ffmpeg-playground/${kind}/${stamp}-${sanitizeFilenameSegment(fileName)}`;
}

function getPathTail(path) {
  if (!path) {
    return '';
  }

  const normalizedPath = String(path).replace(/\/+$/, '');
  const segments = normalizedPath.split('/');
  return segments[segments.length - 1] || normalizedPath;
}

function inferMimeTypeFromName(fileName) {
  const extension = String(fileName || '').split('.').pop()?.toLowerCase();
  if (extension === 'png') {
    return 'image/png';
  }
  if (extension === 'jpg' || extension === 'jpeg') {
    return 'image/jpeg';
  }
  if (extension === 'webp') {
    return 'image/webp';
  }
  if (extension === 'mov') {
    return 'video/quicktime';
  }
  if (extension === 'mp4') {
    return 'video/mp4';
  }
  return 'application/octet-stream';
}

function scrollElementIntoView(element) {
  if (element && typeof element.scrollIntoView === 'function') {
    element.scrollIntoView({ block: 'center' });
  }
}

function extractBase64Payload(dataUrl) {
  const commaIndex = String(dataUrl).indexOf(',');
  if (commaIndex < 0) {
    throw new Error('Bundled demo media is not encoded as a data URL.');
  }

  return dataUrl.slice(commaIndex + 1);
}

export function buildSuggestedOutputPath(inputPath, stamp = Date.now(), suffix = 'reencoded', extension = 'mp4') {
  if (!inputPath) {
    return '';
  }

  const separatorIndex = inputPath.lastIndexOf('/');
  const directory = separatorIndex >= 0 ? inputPath.slice(0, separatorIndex) : '';
  const filename = separatorIndex >= 0 ? inputPath.slice(separatorIndex + 1) : inputPath;
  const basename = filename.replace(/\.[^./]+$/, '');
  const outputName = `${basename || 'file'}-${suffix}-${stamp}.${extension}`;

  return directory ? `${directory}/${outputName}` : outputName;
}

async function blobToBase64(blob) {
  if (typeof blob.arrayBuffer === 'function') {
    const arrayBuffer = await blob.arrayBuffer();
    const bytes = new Uint8Array(arrayBuffer);
    const chunkSize = 0x8000;
    let binary = '';

    for (let index = 0; index < bytes.length; index += chunkSize) {
      const chunk = bytes.subarray(index, index + chunkSize);
      binary += String.fromCharCode(...chunk);
    }

    return btoa(binary);
  }

  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onerror = () => {
      reject(reader.error ?? new Error('Could not read the selected file.'));
    };

    reader.onload = () => {
      if (typeof reader.result !== 'string') {
        reject(new Error('Could not encode the selected file.'));
        return;
      }

      const commaIndex = reader.result.indexOf(',');
      resolve(commaIndex >= 0 ? reader.result.slice(commaIndex + 1) : reader.result);
    };

    reader.readAsDataURL(blob);
  });
}

export function normalizeErrorMessage(error) {
  if (typeof error === 'string') {
    return error;
  }

  if (error && typeof error === 'object' && 'message' in error && typeof error.message === 'string') {
    return error.message;
  }

  return 'Unknown error';
}

export function createExampleApp({
  root,
  ffmpeg,
  filesystem,
  cacheDirectory,
  now = () => Date.now(),
  logger = console,
}) {
  if (!root) {
    throw new Error('A root element is required to mount the example app.');
  }
  if (!filesystem) {
    throw new Error('A filesystem implementation is required to stage picked files.');
  }

  root.innerHTML = createInitialMarkup();

  const refs = {
    refreshRuntimeButton: root.querySelector('#refreshRuntimeButton'),
    runChecksButton: root.querySelector('#runChecksButton'),
    showImageWorkflowButton: root.querySelector('#showImageWorkflowButton'),
    showVideoWorkflowButton: root.querySelector('#showVideoWorkflowButton'),
    imagePanels: root.querySelector('#imagePanels'),
    videoPanels: root.querySelector('#videoPanels'),
    capabilitiesGrid: root.querySelector('#capabilitiesGrid'),
    checksList: root.querySelector('#checksList'),
    platformValue: root.querySelector('#platformValue'),
    versionValue: root.querySelector('#versionValue'),
    pipelineValue: root.querySelector('#pipelineValue'),
    progressFill: root.querySelector('#progressFill'),
    progressLabel: root.querySelector('#progressLabel'),
    jobIdValue: root.querySelector('#jobIdValue'),
    jobStateValue: root.querySelector('#jobStateValue'),
    outputValue: root.querySelector('#outputValue'),
    eventLog: root.querySelector('#eventLog'),
    widthField: root.querySelector('#widthField'),
    heightField: root.querySelector('#heightField'),
    bitrateField: root.querySelector('#bitrateField'),
    pickVideoButton: root.querySelector('#pickVideoButton'),
    loadDemoVideoButton: root.querySelector('#loadDemoVideoButton'),
    videoWorkflowSection: root.querySelector('#videoWorkflowSection'),
    videoPickerInput: root.querySelector('#videoPickerInput'),
    selectedVideoLabel: root.querySelector('#selectedVideoLabel'),
    selectedVideoOutputLabel: root.querySelector('#selectedVideoOutputLabel'),
    queueReencodeButton: root.querySelector('#queueReencodeButton'),
    unsupportedSmokeButton: root.querySelector('#unsupportedSmokeButton'),
    manualHint: root.querySelector('#manualHint'),
    pickImageButton: root.querySelector('#pickImageButton'),
    loadDemoImageButton: root.querySelector('#loadDemoImageButton'),
    imageWorkflowSection: root.querySelector('#imageWorkflowSection'),
    imagePickerInput: root.querySelector('#imagePickerInput'),
    selectedImageLabel: root.querySelector('#selectedImageLabel'),
    selectedImageOutputLabel: root.querySelector('#selectedImageOutputLabel'),
    imageFormatField: root.querySelector('#imageFormatField'),
    imageQualityField: root.querySelector('#imageQualityField'),
    convertImageButton: root.querySelector('#convertImageButton'),
    imageHint: root.querySelector('#imageHint'),
    convertedImageStatus: root.querySelector('#convertedImageStatus'),
    selectedImagePreview: root.querySelector('#selectedImagePreview'),
    convertedImagePreview: root.querySelector('#convertedImagePreview'),
  };

  const state = {
    platform: 'Loading…',
    version: 'Loading…',
    capabilities: null,
    currentJobId: '',
    progress: 0,
    progressState: 'idle',
    progressMessage: 'Waiting for events',
    outputPath: '',
    selectedVideoInput: null,
    selectedVideoOutputPath: '',
    selectedImageInput: null,
    selectedImageOutput: null,
    selectedImagePreviewSrc: '',
    convertedImagePreviewSrc: '',
    logs: [],
    checks: [],
    activeWorkflow: 'image',
  };

  let progressListenerHandle = null;

  function pushLog(kind, message) {
    state.logs.unshift({
      id: `${now()}-${state.logs.length}`,
      kind,
      message,
    });
    state.logs = state.logs.slice(0, 30);
    renderLog();
    logger[kind === 'error' ? 'error' : 'log'](`[example-app] ${message}`);
  }

  function revokePreview(previewKey) {
    const value = state[previewKey];
    if (typeof value === 'string' && value.startsWith('blob:')) {
      URL.revokeObjectURL(value);
    }
  }

  async function resolveSandboxUri(relativePath) {
    const uriResult = await filesystem.getUri({
      path: relativePath,
      directory: cacheDirectory,
    });

    return uriResult.uri ?? relativePath;
  }

  async function stagePickedFile(file, kind) {
    const relativePath = buildRelativeSandboxPath(kind, file.name || `${kind}.bin`, now());
    const data = await blobToBase64(file);

    await filesystem.writeFile({
      path: relativePath,
      data,
      directory: cacheDirectory,
      recursive: true,
    });

    return {
      name: file.name || `${kind}.bin`,
      relativePath,
      uri: await resolveSandboxUri(relativePath),
      mimeType: file.type || inferMimeTypeFromName(file.name),
    };
  }

  async function stageBundledDemoMedia(demoMedia, kind) {
    const relativePath = buildRelativeSandboxPath(kind, demoMedia.name, now());
    const data = extractBase64Payload(demoMedia.dataUrl);

    await filesystem.writeFile({
      path: relativePath,
      data,
      directory: cacheDirectory,
      recursive: true,
    });

    return {
      name: demoMedia.name,
      relativePath,
      uri: await resolveSandboxUri(relativePath),
      mimeType: demoMedia.mimeType,
    };
  }

  async function buildPreviewDataUrl(relativePath, mimeType) {
    const fileResult = await filesystem.readFile({
      path: relativePath,
      directory: cacheDirectory,
    });

    if (typeof fileResult.data !== 'string') {
      throw new Error('Filesystem did not return a base64 payload.');
    }

    return `data:${mimeType};base64,${fileResult.data}`;
  }

  function getCapability(featureName) {
    return state.capabilities?.features?.[featureName];
  }

  function isFeatureRunnable(featureName) {
    return ['available', 'experimental'].includes(getCapability(featureName)?.status ?? '');
  }

  function renderSummary() {
    refs.platformValue.textContent = state.platform;
    refs.versionValue.textContent = state.version;

    const reencodeCapability = state.capabilities?.features?.reencodeVideo;
    if (!reencodeCapability) {
      refs.pipelineValue.textContent = 'Checking…';
      return;
    }

    const label = formatStatusLabel(reencodeCapability.status);
    refs.pipelineValue.textContent = reencodeCapability.reason ? `${label}: ${reencodeCapability.reason}` : label;
  }

  function renderWorkflowPanels() {
    const showImageWorkflow = state.activeWorkflow !== 'video';

    refs.imagePanels.hidden = !showImageWorkflow;
    refs.videoPanels.hidden = showImageWorkflow;
    refs.showImageWorkflowButton.setAttribute('aria-pressed', String(showImageWorkflow));
    refs.showVideoWorkflowButton.setAttribute('aria-pressed', String(!showImageWorkflow));
  }

  function renderImageFormatAvailability() {
    const webpOption = refs.imageFormatField.querySelector('option[value="webp"]');
    const webpSupported = state.platform !== 'ios';

    if (webpOption) {
      webpOption.disabled = !webpSupported;
      webpOption.textContent = webpSupported ? 'WebP' : 'WebP (Android only)';
    }

    if (!webpSupported && normalizeImageFormat(refs.imageFormatField.value) === 'webp') {
      refs.imageFormatField.value = 'jpeg';
    }
  }

  function renderCapabilities() {
    refs.capabilitiesGrid.replaceChildren();

    const features = state.capabilities?.features;
    if (!features) {
      const placeholder = root.ownerDocument.createElement('p');
      placeholder.className = 'muted';
      placeholder.textContent = 'Capability matrix not loaded yet.';
      refs.capabilitiesGrid.appendChild(placeholder);
      return;
    }

    FEATURE_ORDER.forEach((featureName) => {
      const capability = features[featureName];
      if (!capability) {
        return;
      }

      const card = root.ownerDocument.createElement('article');
      card.className = 'capability-card';
      card.dataset.feature = featureName;

      const title = root.ownerDocument.createElement('h3');
      title.textContent = formatFeatureLabel(featureName);

      const badge = root.ownerDocument.createElement('span');
      badge.className = `badge badge-${capability.status}`;
      badge.textContent = formatStatusLabel(capability.status);

      const detail = root.ownerDocument.createElement('p');
      detail.className = 'muted';
      detail.textContent = capability.reason ?? 'No extra notes for this feature on the current platform.';

      card.append(title, badge, detail);
      refs.capabilitiesGrid.appendChild(card);
    });
  }

  function renderChecks() {
    refs.checksList.replaceChildren();

    if (state.checks.length === 0) {
      const item = root.ownerDocument.createElement('li');
      item.className = 'check-item check-item-empty';
      item.textContent = 'Checks have not been run yet.';
      refs.checksList.appendChild(item);
      return;
    }

    state.checks.forEach((check) => {
      const item = root.ownerDocument.createElement('li');
      item.className = 'check-item';

      const badge = root.ownerDocument.createElement('span');
      badge.className = `badge badge-${check.status}`;
      badge.textContent = formatStatusLabel(check.status);

      const body = root.ownerDocument.createElement('div');
      const title = root.ownerDocument.createElement('strong');
      title.textContent = check.label;
      const detail = root.ownerDocument.createElement('p');
      detail.className = 'muted';
      detail.textContent = check.detail;

      body.append(title, detail);
      item.append(badge, body);
      refs.checksList.appendChild(item);
    });
  }

  function renderProgress() {
    refs.jobIdValue.textContent = state.currentJobId || 'No job yet';
    refs.jobStateValue.textContent = state.progressState === 'idle' ? 'Idle' : state.progressState;
    refs.outputValue.textContent = state.outputPath || 'No output yet';
    refs.progressFill.style.width = `${Math.round(clampProgress(state.progress) * 100)}%`;
    refs.progressLabel.textContent = state.progressMessage;
  }

  function renderVideoSelection() {
    refs.selectedVideoLabel.textContent = state.selectedVideoInput
      ? `${state.selectedVideoInput.name} staged in the app cache.`
      : 'No video selected yet.';

    refs.selectedVideoOutputLabel.textContent = state.selectedVideoOutputPath
      ? getPathTail(state.selectedVideoOutputPath)
      : 'Output path will be generated after you pick a source video.';

    refs.queueReencodeButton.disabled = !isFeatureRunnable('reencodeVideo') || !state.selectedVideoInput;
    refs.unsupportedSmokeButton.disabled = isFeatureRunnable('reencodeVideo');

    refs.manualHint.textContent = isFeatureRunnable('reencodeVideo')
      ? 'Pick a source video or load the bundled sample, then queue the native re-encode job.'
      : 'This platform does not expose a real native video re-encode pipeline yet. Use the unsupported-path check instead.';
  }

  function renderImageSelection() {
    refs.selectedImageLabel.textContent = state.selectedImageInput
      ? `${state.selectedImageInput.name} staged in the app cache.`
      : 'No image selected yet.';

    refs.selectedImageOutputLabel.textContent = state.selectedImageOutput?.uri
      ? getPathTail(state.selectedImageOutput.uri)
      : 'Pick an image to generate an output path.';

    refs.convertImageButton.disabled = !isFeatureRunnable('convertImage') || !state.selectedImageInput;
    refs.imageHint.textContent = isFeatureRunnable('convertImage')
      ? state.platform === 'ios'
        ? 'Pick an image from Photos or load the bundled sample, then convert it into JPEG or PNG.'
        : 'Pick an image from Photos or load the bundled sample, then convert it into WebP, JPEG, or PNG.'
      : 'This platform does not expose native image conversion yet.';
    refs.selectedImagePreview.hidden = !state.selectedImagePreviewSrc;
    refs.convertedImagePreview.hidden = !state.convertedImagePreviewSrc;
    refs.selectedImagePreview.src = state.selectedImagePreviewSrc;
    refs.convertedImagePreview.src = state.convertedImagePreviewSrc;
  }

  function renderLog() {
    refs.eventLog.replaceChildren();

    if (state.logs.length === 0) {
      const item = root.ownerDocument.createElement('li');
      item.className = 'log-item log-item-empty';
      item.textContent = 'Waiting for activity.';
      refs.eventLog.appendChild(item);
      return;
    }

    state.logs.forEach((entry) => {
      const item = root.ownerDocument.createElement('li');
      item.className = 'log-item';

      const badge = root.ownerDocument.createElement('span');
      badge.className = `log-kind log-kind-${entry.kind}`;
      badge.textContent = entry.kind;

      const text = root.ownerDocument.createElement('span');
      text.textContent = entry.message;

      item.append(badge, text);
      refs.eventLog.appendChild(item);
    });
  }

  async function updateSelectedImageOutput() {
    if (!state.selectedImageInput) {
      state.selectedImageOutput = null;
      renderImageSelection();
      return;
    }

    const format = normalizeImageFormat(refs.imageFormatField.value);
    const nextRelativePath = buildSuggestedOutputPath(
      state.selectedImageInput.relativePath,
      now(),
      'converted',
      format
    );

    state.selectedImageOutput = {
      relativePath: nextRelativePath,
      uri: await resolveSandboxUri(nextRelativePath),
      format,
      mimeType: IMAGE_MIME_TYPES[format],
    };

    renderImageSelection();
  }

  function parsePositiveInteger(field, label) {
    const value = Number.parseInt(field.value, 10);
    if (!Number.isFinite(value) || value <= 0) {
      throw new Error(`${label} must be a positive integer.`);
    }
    return value;
  }

  function readReencodeOptions() {
    if (!state.selectedVideoInput || !state.selectedVideoOutputPath) {
      throw new Error('Pick a source video before queueing a re-encode job.');
    }

    const bitrateValue = refs.bitrateField.value.trim();
    const outputPath = buildSuggestedOutputPath(state.selectedVideoInput.uri, now(), 'reencoded', 'mp4');
    state.selectedVideoOutputPath = outputPath;
    renderVideoSelection();

    return {
      inputPath: state.selectedVideoInput.uri,
      outputPath,
      width: parsePositiveInteger(refs.widthField, 'Width'),
      height: parsePositiveInteger(refs.heightField, 'Height'),
      bitrate: bitrateValue ? parsePositiveInteger(refs.bitrateField, 'Bitrate') : undefined,
    };
  }

  function readConvertImageOptions() {
    if (!state.selectedImageInput || !state.selectedImageOutput) {
      throw new Error('Pick a source image before running a conversion.');
    }

    const quality = Number.parseFloat(refs.imageQualityField.value);
    if (Number.isFinite(quality) === false || quality < 0 || quality > 1) {
      throw new Error('Image quality must be a number between 0 and 1.');
    }

    return {
      inputPath: state.selectedImageInput.uri,
      outputPath: state.selectedImageOutput.uri,
      format: state.selectedImageOutput.format,
      quality,
    };
  }

  async function refreshRuntime() {
    const [versionResult, capabilitiesResult] = await Promise.all([ffmpeg.getPluginVersion(), ffmpeg.getCapabilities()]);

    state.version = versionResult.version;
    state.platform = capabilitiesResult.platform;
    state.capabilities = capabilitiesResult;
    renderImageFormatAvailability();
    renderSummary();
    renderCapabilities();
    renderVideoSelection();
    renderImageSelection();
    pushLog('info', `Loaded plugin version ${versionResult.version} on ${capabilitiesResult.platform}.`);
    return capabilitiesResult;
  }

  function handleProgressEvent(event) {
    state.currentJobId = event.jobId ?? state.currentJobId;
    state.progress = clampProgress(event.progress);
    state.progressState = event.state ?? state.progressState;
    state.progressMessage = event.message ?? `Job ${state.progressState}`;
    if (event.outputPath) {
      state.outputPath = event.outputPath;
    }

    renderProgress();
    pushLog('info', `Progress update: ${event.state} at ${Math.round(state.progress * 100)}%.`);
  }

  async function registerProgressListener() {
    if (progressListenerHandle) {
      return progressListenerHandle;
    }

    progressListenerHandle = await ffmpeg.addListener('progress', handleProgressEvent);
    pushLog('info', 'Registered progress listener.');
    return progressListenerHandle;
  }

  async function queueReencode(options = readReencodeOptions()) {
    state.progress = 0;
    state.progressState = 'queued';
    state.progressMessage = 'Queued for native processing';
    state.outputPath = options.outputPath;
    renderProgress();
    scrollElementIntoView(refs.progressLabel);

    const acceptedJob = await ffmpeg.reencodeVideo(options);
    state.currentJobId = acceptedJob?.jobId ?? state.currentJobId ?? 'Accepted without job id';
    renderProgress();
    pushLog('info', `Queued re-encode request for ${options.inputPath}.`);
    return acceptedJob;
  }

  async function convertImage(options = readConvertImageOptions()) {
    const result = await ffmpeg.convertImage(options);
    state.outputPath = result.outputPath;
    refs.convertedImageStatus.textContent = `Converted ${state.selectedImageInput?.name ?? 'image'} to ${result.format} at ${result.outputPath}.`;
    scrollElementIntoView(refs.convertedImageStatus);

    revokePreview('convertedImagePreviewSrc');
    state.convertedImagePreviewSrc = await buildPreviewDataUrl(
      state.selectedImageOutput.relativePath,
      state.selectedImageOutput.mimeType
    );
    renderProgress();
    renderImageSelection();
    pushLog('info', `Converted image to ${result.format}.`);
    return result;
  }

  async function runUnsupportedSmokeTest() {
    const reencodeStatus = state.capabilities?.features?.reencodeVideo?.status;
    if (['available', 'experimental'].includes(reencodeStatus ?? '')) {
      state.checks = [
        {
          label: 'Unsupported re-encode smoke test',
          status: 'skipped',
          detail: 'Skipped because this platform advertises a native media pipeline.',
        },
      ];
      renderChecks();
      scrollElementIntoView(refs.checksList);
      pushLog('info', 'Skipped unsupported-path smoke test on a platform with a native media pipeline.');
      return;
    }

    try {
      await ffmpeg.reencodeVideo({
        inputPath: 'file:///tmp/input.mov',
        outputPath: 'file:///tmp/output.mp4',
        width: 320,
        height: 180,
        bitrate: 256000,
      });
      state.checks = [
        {
          label: 'Unsupported re-encode smoke test',
          status: 'failed',
          detail: 'The call resolved unexpectedly on a platform that reported no media pipeline.',
        },
      ];
      renderChecks();
      scrollElementIntoView(refs.checksList);
      pushLog('error', 'Unsupported-path smoke test unexpectedly resolved.');
    } catch (error) {
      const message = normalizeErrorMessage(error);
      state.checks = [
        {
          label: 'Unsupported re-encode smoke test',
          status: 'passed',
          detail: message,
        },
      ];
      renderChecks();
      scrollElementIntoView(refs.checksList);
      pushLog('info', `Unsupported-path smoke test rejected as expected: ${message}`);
    }
  }

  async function runChecks() {
    const checks = [];

    try {
      const versionResult = await ffmpeg.getPluginVersion();
      checks.push({
        label: 'Plugin version endpoint',
        status: 'passed',
        detail: `Resolved version "${versionResult.version}".`,
      });
    } catch (error) {
      checks.push({
        label: 'Plugin version endpoint',
        status: 'failed',
        detail: normalizeErrorMessage(error),
      });
    }

    try {
      const capabilitiesResult = await refreshRuntime();
      checks.push({
        label: 'Capability matrix endpoint',
        status: 'passed',
        detail: `Resolved runtime capabilities for ${capabilitiesResult.platform}.`,
      });
    } catch (error) {
      checks.push({
        label: 'Capability matrix endpoint',
        status: 'failed',
        detail: normalizeErrorMessage(error),
      });
    }

    try {
      await registerProgressListener();
      checks.push({
        label: 'Progress listener registration',
        status: 'passed',
        detail: 'Listener registration completed without throwing.',
      });
    } catch (error) {
      checks.push({
        label: 'Progress listener registration',
        status: 'failed',
        detail: normalizeErrorMessage(error),
      });
    }

    if (['unimplemented', 'unavailable'].includes(getCapability('reencodeVideo')?.status ?? '')) {
      try {
        await ffmpeg.reencodeVideo({
          inputPath: 'file:///tmp/input.mov',
          outputPath: 'file:///tmp/output.mp4',
          width: 320,
          height: 180,
          bitrate: 256000,
        });
        checks.push({
          label: 'Unsupported re-encode contract',
          status: 'failed',
          detail: 'Call resolved unexpectedly.',
        });
      } catch (error) {
        checks.push({
          label: 'Unsupported re-encode contract',
          status: 'passed',
          detail: normalizeErrorMessage(error),
        });
      }
    } else {
      checks.push({
        label: 'Unsupported re-encode contract',
        status: 'skipped',
        detail: 'Skipped because this platform reports a real media pipeline.',
      });
    }

    if (['unimplemented', 'unavailable'].includes(getCapability('convertImage')?.status ?? '')) {
      try {
        await ffmpeg.convertImage({
          inputPath: 'file:///tmp/input.png',
          outputPath: 'file:///tmp/output.webp',
          format: 'webp',
          quality: 0.85,
        });
        checks.push({
          label: 'Unsupported image conversion contract',
          status: 'failed',
          detail: 'Call resolved unexpectedly.',
        });
      } catch (error) {
        checks.push({
          label: 'Unsupported image conversion contract',
          status: 'passed',
          detail: normalizeErrorMessage(error),
        });
      }
    } else {
      checks.push({
        label: 'Unsupported image conversion contract',
        status: 'skipped',
        detail: 'Skipped because this platform reports a native image conversion path.',
      });
    }

    state.checks = checks;
    renderChecks();
    scrollElementIntoView(refs.checksList);
    pushLog('info', `Runtime checks completed with ${checks.length} results.`);
    return checks;
  }

  async function handleVideoPicked(file) {
    if (!file) {
      return;
    }

    state.selectedVideoInput = await stagePickedFile(file, 'imports');
    state.selectedVideoOutputPath = buildSuggestedOutputPath(state.selectedVideoInput.uri, now(), 'reencoded', 'mp4');
    renderVideoSelection();
    pushLog('info', `Staged video ${state.selectedVideoInput.name}.`);
  }

  async function loadDemoVideo() {
    state.selectedVideoInput = await stageBundledDemoMedia(DEMO_MEDIA.video, 'imports');
    state.selectedVideoOutputPath = buildSuggestedOutputPath(state.selectedVideoInput.uri, now(), 'reencoded', 'mp4');
    renderVideoSelection();
    pushLog('info', `Loaded bundled demo video ${state.selectedVideoInput.name}.`);
  }

  async function handleImagePicked(file) {
    if (!file) {
      return;
    }

    revokePreview('selectedImagePreviewSrc');
    revokePreview('convertedImagePreviewSrc');
    state.convertedImagePreviewSrc = '';
    refs.convertedImageStatus.textContent = 'No converted image yet.';

    state.selectedImageInput = await stagePickedFile(file, 'imports');
    state.selectedImagePreviewSrc = await buildPreviewDataUrl(
      state.selectedImageInput.relativePath,
      state.selectedImageInput.mimeType
    );
    await updateSelectedImageOutput();
    renderImageSelection();
    pushLog('info', `Staged image ${state.selectedImageInput.name}.`);
  }

  async function loadDemoImage() {
    revokePreview('selectedImagePreviewSrc');
    revokePreview('convertedImagePreviewSrc');
    state.convertedImagePreviewSrc = '';
    refs.convertedImageStatus.textContent = 'No converted image yet.';

    state.selectedImageInput = await stageBundledDemoMedia(DEMO_MEDIA.image, 'imports');
    state.selectedImagePreviewSrc = await buildPreviewDataUrl(
      state.selectedImageInput.relativePath,
      state.selectedImageInput.mimeType
    );
    await updateSelectedImageOutput();
    renderImageSelection();
    pushLog('info', `Loaded bundled demo image ${state.selectedImageInput.name}.`);
  }

  async function handleQueueReencodeClick() {
    try {
      await queueReencode();
    } catch (error) {
      const message = normalizeErrorMessage(error);
      pushLog('error', `Re-encode request failed: ${message}`);
      state.progressState = 'failed';
      state.progressMessage = message;
      renderProgress();
    }
  }

  async function handleConvertImageClick() {
    try {
      await convertImage();
    } catch (error) {
      const message = normalizeErrorMessage(error);
      refs.convertedImageStatus.textContent = message;
      pushLog('error', `Image conversion failed: ${message}`);
    }
  }

  refs.refreshRuntimeButton.addEventListener('click', async () => {
    try {
      await refreshRuntime();
    } catch (error) {
      pushLog('error', `Failed to refresh runtime data: ${normalizeErrorMessage(error)}`);
    }
  });

  refs.runChecksButton.addEventListener('click', async () => {
    await runChecks();
  });

  refs.showImageWorkflowButton.addEventListener('click', () => {
    state.activeWorkflow = 'image';
    renderWorkflowPanels();
  });

  refs.showVideoWorkflowButton.addEventListener('click', () => {
    state.activeWorkflow = 'video';
    renderWorkflowPanels();
  });

  refs.pickVideoButton.addEventListener('click', () => {
    refs.videoPickerInput.click();
  });

  refs.videoPickerInput.addEventListener('change', async () => {
    const file = refs.videoPickerInput.files?.[0];
    try {
      await handleVideoPicked(file);
    } catch (error) {
      pushLog('error', `Failed to pick video: ${normalizeErrorMessage(error)}`);
    } finally {
      refs.videoPickerInput.value = '';
    }
  });

  refs.loadDemoVideoButton.addEventListener('click', async () => {
    try {
      await loadDemoVideo();
    } catch (error) {
      pushLog('error', `Failed to load demo video: ${normalizeErrorMessage(error)}`);
    }
  });

  refs.queueReencodeButton.addEventListener('click', async () => {
    await handleQueueReencodeClick();
  });

  refs.unsupportedSmokeButton.addEventListener('click', async () => {
    await runUnsupportedSmokeTest();
  });

  refs.pickImageButton.addEventListener('click', () => {
    refs.imagePickerInput.click();
  });

  refs.imagePickerInput.addEventListener('change', async () => {
    const file = refs.imagePickerInput.files?.[0];
    try {
      await handleImagePicked(file);
    } catch (error) {
      pushLog('error', `Failed to pick image: ${normalizeErrorMessage(error)}`);
    } finally {
      refs.imagePickerInput.value = '';
    }
  });

  refs.loadDemoImageButton.addEventListener('click', async () => {
    try {
      await loadDemoImage();
    } catch (error) {
      pushLog('error', `Failed to load demo image: ${normalizeErrorMessage(error)}`);
    }
  });

  refs.imageFormatField.addEventListener('change', async () => {
    await updateSelectedImageOutput();
  });

  refs.convertImageButton.addEventListener('click', async () => {
    await handleConvertImageClick();
  });

  renderSummary();
  renderWorkflowPanels();
  renderCapabilities();
  renderChecks();
  renderProgress();
  renderVideoSelection();
  renderImageSelection();
  renderLog();

  return {
    refs,
    state,
    refreshRuntime,
    registerProgressListener,
    runChecks,
    queueReencode,
    convertImage,
    handleVideoPicked,
    handleImagePicked,
    loadDemoVideo,
    loadDemoImage,
    init: async () => {
      await refreshRuntime();
      await registerProgressListener();
    },
    destroy: async () => {
      revokePreview('selectedImagePreviewSrc');
      revokePreview('convertedImagePreviewSrc');

      if (progressListenerHandle?.remove) {
        await progressListenerHandle.remove();
        progressListenerHandle = null;
      }
    },
  };
}
