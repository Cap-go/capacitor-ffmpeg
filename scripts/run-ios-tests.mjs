import { execFileSync, spawnSync } from 'node:child_process';

const scheme = 'CapgoCapacitorFfmpeg';

function parseRuntimeVersion(runtimeIdentifier) {
  const match = runtimeIdentifier.match(/iOS-(\d+)-(\d+)(?:-(\d+))?$/);
  if (!match) {
    return [0, 0, 0];
  }

  return [Number(match[1]), Number(match[2]), Number(match[3] ?? 0)];
}

function compareVersions(left, right) {
  for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
    const leftPart = left[index] ?? 0;
    const rightPart = right[index] ?? 0;

    if (leftPart !== rightPart) {
      return rightPart - leftPart;
    }
  }

  return 0;
}

function resolveDestination() {
  if (process.env.IOS_TEST_DESTINATION) {
    return process.env.IOS_TEST_DESTINATION;
  }

  if (process.env.IOS_TEST_SIMULATOR_ID) {
    return `platform=iOS Simulator,id=${process.env.IOS_TEST_SIMULATOR_ID}`;
  }

  const devicesJson = execFileSync('xcrun', ['simctl', 'list', 'devices', 'available', '--json'], {
    encoding: 'utf8',
  });
  const { devices } = JSON.parse(devicesJson);

  const candidates = Object.entries(devices)
    .filter(([runtimeIdentifier]) => runtimeIdentifier.includes('iOS'))
    .sort(([leftRuntime], [rightRuntime]) =>
      compareVersions(parseRuntimeVersion(leftRuntime), parseRuntimeVersion(rightRuntime)),
    )
    .flatMap(([, runtimeDevices]) =>
      runtimeDevices
        .filter((device) => device.isAvailable)
        .sort((left, right) => {
          const leftIsPhone = left.name.startsWith('iPhone');
          const rightIsPhone = right.name.startsWith('iPhone');

          if (leftIsPhone !== rightIsPhone) {
            return leftIsPhone ? -1 : 1;
          }

          return left.name.localeCompare(right.name);
        }),
    );

  const simulator = candidates[0];
  if (!simulator) {
    throw new Error(
      'No available iOS simulator was found. Set IOS_TEST_DESTINATION or IOS_TEST_SIMULATOR_ID to override.',
    );
  }

  return `platform=iOS Simulator,id=${simulator.udid}`;
}

const destination = resolveDestination();
const result = spawnSync('xcodebuild', ['-scheme', scheme, '-destination', destination, 'test'], { stdio: 'inherit' });

if (result.error) {
  throw result.error;
}

process.exit(result.status ?? 1);
