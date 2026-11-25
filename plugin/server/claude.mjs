// Where the claude command is: what to run, and its first arguments. Not every program is
// started with the folders a terminal knows, so its usual places are looked in too.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const isFile = (file) => { try { return fs.statSync(file).isFile(); } catch { return false; } };

export function claudeCommand(platform = process.platform) {
  const windows = platform === 'win32';
  const folders = [
    ...(process.env.PATH || '').split(windows ? ';' : ':').map((folder) => folder.replace(/^"|"$/g, '')).filter(Boolean),
    path.join(os.homedir(), '.local', 'bin'),
    ...(windows ? [path.join(process.env.APPDATA || os.homedir(), 'npm')] : ['/opt/homebrew/bin', '/usr/local/bin']),
  ];
  for (const folder of folders) {
    const file = path.join(folder, windows ? 'claude.exe' : 'claude');
    if (isFile(file)) return [file];
    // installed with npm on Windows: a .cmd, which only a shell runs
    if (windows && isFile(path.join(folder, 'claude.cmd'))) {
      const installed = path.join(folder, 'node_modules', '@anthropic-ai', 'claude-code');
      if (isFile(path.join(installed, 'bin', 'claude.exe'))) return [path.join(installed, 'bin', 'claude.exe')];
      if (isFile(path.join(installed, 'cli.js'))) return [process.execPath, path.join(installed, 'cli.js')];
    }
  }
  return ['claude'];
}
