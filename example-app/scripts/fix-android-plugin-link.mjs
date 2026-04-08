#!/usr/bin/env bun

import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const rootDir = path.resolve(import.meta.dir, '..');
const settingsPath = path.join(rootDir, 'android', 'capacitor.settings.gradle');
const desiredLine = "project(':capgo-capacitor-ffmpeg').projectDir = new File(settingsDir, '../../android')";

const current = readFileSync(settingsPath, 'utf8');
const next = current.replace(
  /project\(':capgo-capacitor-ffmpeg'\)\.projectDir = .*/,
  desiredLine
);

if (current !== next) {
  writeFileSync(settingsPath, next);
}
