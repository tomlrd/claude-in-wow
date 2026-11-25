// The player's own folder for what is kept from a run to the next: ~/.claude-in-wow.
// CIW_HOME_DIR, CIW_SILENT_DIR (tests, and the silent mode's own tools): other folders.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export function homeDir() {
  return process.env.CIW_HOME_DIR || path.join(os.homedir(), '.claude-in-wow');
}

export function dataDir() {
  const dir = process.env.CIW_SILENT_DIR || homeDir();
  try { fs.mkdirSync(dir, { recursive: true }); } catch { /* told when something is written */ }
  return dir;
}
