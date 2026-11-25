// The silent mode started with the computer, when the player asks for it (Windows): a
// small script in the Startup folder runs, without a window, a launcher kept in the
// player's own folder (~/.claude-in-wow), which starts the newest version of the
// plugin found next to this one. And what is there for the answers to work (check).
// CIW_STARTUP_DIR, CIW_HOME_DIR (tests): other folders.

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { claudeCommand } from './claude.mjs';
import { findGames, hasAddon } from './game.mjs';
import { homeDir as home } from './home.mjs';
import { status } from './silent-mode.mjs';
import { slotsThere } from './slots.mjs';

const plugin = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const script = () => path.join(process.env.CIW_STARTUP_DIR
  || path.join(process.env.APPDATA || '', 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup'), 'claude-in-wow.vbs');

const LAUNCHER = `// Starts claude-in-wow's silent mode: the newest version of the plugin.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const { plugin, dir } = JSON.parse(fs.readFileSync(new URL('./autostart.json', import.meta.url), 'utf8'));
const numbers = (name) => name.split('.').map(Number);
const newer = (a, b) => numbers(b).reduce((order, n, i) => order || n - (numbers(a)[i] || 0), 0);
let found = plugin;
if (/^\\d+(\\.\\d+)*$/.test(path.basename(plugin))) {
  const versions = fs.readdirSync(path.dirname(plugin)).filter((name) => /^\\d+(\\.\\d+)*$/.test(name)
    && fs.existsSync(path.join(path.dirname(plugin), name, 'server', 'silent-mode.mjs'))).sort(newer);
  if (versions.length) found = path.join(path.dirname(plugin), versions[0]);
}
const { start } = await import(pathToFileURL(path.join(found, 'server', 'silent-mode.mjs')));
start(dir);
`;

export function autostartOn() {
  return fs.existsSync(script());
}

export function setAutostart(on, dir) {
  if (process.platform !== 'win32') return { error: 'Starting with the computer is only done on Windows for now.' };
  if (!on) {
    for (const file of [script(), path.join(home(), 'start.mjs'), path.join(home(), 'autostart.json')]) fs.rmSync(file, { force: true });
    return { autostart: false };
  }
  if (!fs.existsSync(dir)) return { error: `No folder ${dir}.` };
  const launcher = path.join(home(), 'start.mjs');
  fs.mkdirSync(home(), { recursive: true });
  fs.writeFileSync(launcher, LAUNCHER);
  fs.writeFileSync(path.join(home(), 'autostart.json'), JSON.stringify({ plugin, dir }, null, 1));
  // a version manager's folder for one terminal (fnm) goes with it: the real one
  const node = /multishell/i.test(process.execPath) ? fs.realpathSync(process.execPath) : process.execPath;
  const run = [node, launcher].map((file) => `""${file}""`).join(' ');
  fs.writeFileSync(script(), `﻿' claude-in-wow: answers the questions asked in the game. Remove this file to stop it.\r\nCreateObject("WScript.Shell").Run "${run}", 0, False\r\n`, 'utf16le');
  return { autostart: true, file: script() };
}

// Claude Code's answer to a command, in the player's own environment.
function claude(args) {
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => key === 'CLAUDE_CONFIG_DIR' || !/^(CLAUDE|ANTHROPIC)/i.test(key)));
  const [program, ...first] = claudeCommand();
  const result = spawnSync(program, [...first, ...args], { encoding: 'utf8', timeout: 20000, windowsHide: true, env });
  return result.error ? null : String(result.stdout || '');
}

// What the answers need, one by one: what is missing is null or false.
export function check() {
  const version = claude(['--version']);
  let signedIn = null;
  if (version !== null) {
    try { signedIn = JSON.parse(claude(['auth', 'status']) || '').loggedIn === true; } catch { signedIn = null; }
  }
  return {
    node: process.version,
    claudeCode: version === null ? null : version.trim(),
    signedIn,
    games: findGames().map((dir) => ({ folder: dir, addon: hasAddon(dir), answerAddons: slotsThere(dir) })),
    silentMode: status().running,
    autostart: process.platform === 'win32' ? autostartOn() : null,
  };
}
