#!/usr/bin/env bun

import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const rootDir = path.resolve(import.meta.dir, '..');
const settingsPath = path.join(rootDir, 'android', 'capacitor.settings.gradle');
const desiredLine = "project(':capgo-capacitor-ffmpeg').projectDir = new File(settingsDir, '../../android')";
const pluginLinePattern = /project\(':capgo-capacitor-ffmpeg'\)\.projectDir = .*/;

const current = readFileSync(settingsPath, 'utf8');
if (!pluginLinePattern.test(current)) {
  throw new Error('Expected capgo-capacitor-ffmpeg plugin projectDir line not found.');
}

const next = current.replace(pluginLinePattern, desiredLine);

if (current !== next) {
  writeFileSync(settingsPath, next);
}
