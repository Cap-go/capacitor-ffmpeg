#!/usr/bin/env bun

import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const rootDir = path.resolve(import.meta.dir, '..');
const packageJson = JSON.parse(readFileSync(path.join(rootDir, 'package.json'), 'utf8'));
const versionLiteral = JSON.stringify(packageJson.version);

const outputs = [
  {
    path: path.join(rootDir, 'src', 'pluginVersion.ts'),
    content: `export const PLUGIN_VERSION = ${versionLiteral};\n`,
  },
  {
    path: path.join(rootDir, 'ios', 'Sources', 'CapacitorFFmpegPlugin', 'PluginVersion.generated.swift'),
    content: `enum CapacitorFFmpegPluginVersion {\n    static let value = ${versionLiteral}\n}\n`,
  },
];

for (const output of outputs) {
  const currentContent = (() => {
    try {
      return readFileSync(output.path, 'utf8');
    } catch {
      return '';
    }
  })();

  if (currentContent !== output.content) {
    writeFileSync(output.path, output.content);
  }
}
