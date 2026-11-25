// Updates of the addon and of this plugin, asked from the game (the addon's Updates.lua).
// What is out is read from the project's releases on GitHub (release.json, which
// tools/package.mjs makes), once a day; nothing is sent about the player. The plugin is
// updated by Claude Code itself. The addon, when the player chose GitHub over CurseForge:
// its zip is downloaded from that release, its print checked, and it takes the place of
// the one installed once the game is closed; the one before is kept. A development copy
// (no "X-Install" in its .toc) is never replaced.
// CIW_RELEASES (tests): a server of this computer in GitHub's place.

import { spawn, spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import zlib from 'node:zlib';
import { claudeCommand } from './claude.mjs';
import { findGames, hasAddon, loadData } from './game.mjs';
import { dataDir } from './home.mjs';
import { NEWS, putNews } from './slots.mjs';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const ADDON = 'claude-in-wow';
const DAY_S = 86400;
const MAX_ZIP = 40e6;
const MAX_FILES = 3000;
const CURSEFORGE = 'https://www.curseforge.com/wow/addons/';

const now = () => Math.floor(Date.now() / 1000);
const numbers = (version) => String(version || '').split('.').map(Number);
export const isVersion = (version) => typeof version === 'string' && /^\d+(\.\d+){1,3}$/.test(version);
export function newer(a, b) {
  const [x, y] = [numbers(a), numbers(b)];
  for (let i = 0; i < Math.max(x.length, y.length); i += 1) if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0);
  return false;
}

// Where the releases are: { api, files } (files: what every download's address starts with).
function source() {
  if (/^http:\/\/127\.0\.0\.1:\d+$/.test(process.env.CIW_RELEASES || '')) return { api: `${process.env.CIW_RELEASES}/latest`, files: `${process.env.CIW_RELEASES}/` };
  let repository = '';
  try { repository = JSON.parse(fs.readFileSync(path.join(ROOT, '.claude-plugin', 'plugin.json'), 'utf8')).repository || ''; } catch { repository = ''; }
  const [, owner, name] = /^https:\/\/github\.com\/([\w.-]+)\/([\w.-]+?)(?:\.git)?\/?$/.exec(repository) || [];
  return owner ? { api: `https://api.github.com/repos/${owner}/${name}/releases/latest`, files: `https://github.com/${owner}/${name}/releases/download/` } : null;
}

const stateFile = () => path.join(dataDir(), 'updates.json');
function readState() {
  try { return JSON.parse(fs.readFileSync(stateFile(), 'utf8')) || {}; } catch { return {}; }
}
function writeState(change) {
  const state = { ...readState(), ...change };
  fs.writeFileSync(stateFile(), JSON.stringify(state, null, 1));
  return state;
}

async function get(url) {
  const answer = await fetch(url, { headers: { 'User-Agent': 'claude-in-wow', Accept: 'application/json, application/octet-stream' }, signal: AbortSignal.timeout(60e3) });
  if (!answer.ok) throw new Error(`network: ${answer.status}`);
  const data = Buffer.from(await answer.arrayBuffer());
  if (data.length > MAX_ZIP) throw new Error('files: too large');
  return data;
}

// The newest release: { addon: { version, url, sha256 }, plugin: { version, needsAddon },
// notes, curseforge }, kept a day; null when there is none.
export async function latest(force = false) {
  const from = source(), state = readState();
  if (!from) return null;
  if (!force && state.checkedAt > now() - DAY_S) return state.latest || null;
  let release = {};
  try { release = JSON.parse((await get(from.api)).toString('utf8')); } catch (error) {
    if (error.message !== 'network: 404') throw error; // none published yet
  }
  const assets = new Map((Array.isArray(release.assets) ? release.assets : []).map(({ name, browser_download_url: url }) => [name, String(url || '')]));
  const ours = (url) => Boolean(url) && url.startsWith(from.files);
  if (!ours(assets.get('release.json'))) {
    writeState({ checkedAt: now(), latest: null });
    return null;
  }
  const told = JSON.parse((await get(assets.get('release.json'))).toString('utf8'));
  const url = assets.get(told.addon?.file);
  const found = {
    addon: isVersion(told.addon?.version) && ours(url) && /^[0-9a-f]{64}$/.test(told.addon?.sha256) ? { version: told.addon.version, url, sha256: told.addon.sha256 } : null,
    plugin: isVersion(told.plugin?.version) ? { version: told.plugin.version, needsAddon: isVersion(told.plugin.needsAddon) ? told.plugin.needsAddon : null } : null,
    notes: notesOf(told.notes),
    curseforge: String(told.curseforge || '').startsWith(CURSEFORGE) ? told.curseforge : null,
  };
  writeState({ checkedAt: now(), latest: found });
  return found;
}

// What is new, a list a language.
function notesOf(notes) {
  return Object.fromEntries(Object.entries(notes && typeof notes === 'object' ? notes : {}).filter(([code, list]) => /^[a-z]{2}[A-Z]{2}$/.test(code) && Array.isArray(list))
    .map(([code, list]) => [code, list.slice(0, 30).map((line) => String(line).replace(/[|\r\n]+/g, ' ').slice(0, 300))]));
}

// ------------------------------------------------------------- what is installed

const addonDir = (wowDir) => path.join(wowDir, 'Interface', 'AddOns', ADDON);
const field = (dir, name) => {
  try { return new RegExp(`^## ${name}: *(.+?)\\s*$`, 'm').exec(fs.readFileSync(path.join(dir, `${ADDON}.toc`), 'utf8'))?.[1] || null; } catch { return null; }
};
export const addonVersion = (wowDir) => field(addonDir(wowDir), 'Version');

export function pluginVersion() {
  try { return JSON.parse(fs.readFileSync(path.join(ROOT, '.claude-plugin', 'plugin.json'), 'utf8')).version; } catch { return null; }
}

// A copy somebody works on: a link, a repository, or one no package made.
function isDevelopment(dir) {
  try {
    return fs.lstatSync(dir).isSymbolicLink() || fs.existsSync(path.join(dir, '.git')) || !field(dir, 'X-Install');
  } catch { return true; }
}

// The marketplace this plugin was installed from; null for a copy read where it is.
function marketplace() {
  const [, name] = /[\\/]cache[\\/]([\w.-]+)[\\/]wow-mcp[\\/]\d+(?:\.\d+)*$/.exec(ROOT) || [];
  return name || null;
}

// Whether the game runs, whichever its version.
export function gameRunning() {
  if (process.env.CIW_GAME_RUNNING) return fs.existsSync(process.env.CIW_GAME_RUNNING);
  if (process.platform === 'win32') {
    const { stdout, error } = spawnSync('tasklist', ['/FO', 'CSV', '/NH'], { encoding: 'utf8', windowsHide: true, timeout: 20000 });
    return Boolean(error) || /^"Wow(Classic)?[TB]?(-ARM64)?\.exe"/im.test(stdout || '');
  }
  const { status, error } = spawnSync('pgrep', ['-f', 'World of Warcraft.*\\.app/Contents/MacOS'], { timeout: 20000 });
  return Boolean(error) || status === 0;
}

// ------------------------------------------------------------- the addon

// The files of a zip, of the addon's folder only: [{ name, data }].
export function unzip(zip) {
  let end = zip.length - 22;
  while (end >= 0 && zip.readUInt32LE(end) !== 0x06054b50) end -= 1;
  if (end < 0) throw new Error('files: not a zip');
  const count = zip.readUInt16LE(end + 10);
  if (count > MAX_FILES) throw new Error('files: too many');
  const files = [];
  let at = zip.readUInt32LE(end + 16), total = 0;
  for (let i = 0; i < count; i += 1) {
    if (zip.readUInt32LE(at) !== 0x02014b50) throw new Error('files: damaged');
    const method = zip.readUInt16LE(at + 10), packed = zip.readUInt32LE(at + 20), size = zip.readUInt32LE(at + 24);
    const [named, extra, comment] = [28, 30, 32].map((offset) => zip.readUInt16LE(at + offset));
    const mode = zip.readUInt32LE(at + 38) >>> 16, local = zip.readUInt32LE(at + 42);
    const name = zip.toString('utf8', at + 46, at + 46 + named);
    at += 46 + named + extra + comment;
    const parts = name.split('/');
    if (parts[0] !== ADDON || /[\\:*?"<>|\x00-\x1f]/.test(name) || parts.includes('..') || parts.includes('.') || (mode & 0xf000) === 0xa000) throw new Error('files: a name out of place');
    if (name.endsWith('/')) continue;
    total += size;
    if (total > MAX_ZIP || (method !== 0 && method !== 8)) throw new Error('files: too large');
    const start = local + 30 + zip.readUInt16LE(local + 26) + zip.readUInt16LE(local + 28);
    const raw = zip.subarray(start, start + packed);
    const data = method === 8 ? zlib.inflateRawSync(raw, { maxOutputLength: MAX_ZIP }) : raw;
    if (data.length !== size) throw new Error('files: damaged');
    files.push({ name: parts.slice(1).join('/'), data });
  }
  if (!files.some(({ name }) => name === `${ADDON}.toc`)) throw new Error('files: not the addon');
  return files;
}

const staged = () => path.join(dataDir(), 'updates');
const kept = (wowDir) => path.join(staged(), `before-${path.basename(wowDir).replace(/\W/g, '')}`);

// Downloads the addon of a release, for when the game is closed.
async function stage(addon, wowDir) {
  const zip = await get(addon.url);
  if (crypto.createHash('sha256').update(zip).digest('hex') !== addon.sha256) throw new Error('checksum');
  unzip(zip); // whole, and nothing out of place
  fs.mkdirSync(staged(), { recursive: true });
  const file = path.join(staged(), `${addon.version}.zip`);
  fs.writeFileSync(file, zip);
  const waiting = (readState().waiting || []).filter((one) => one.wowDir !== wowDir);
  writeState({ waiting: [...waiting, { wowDir, version: addon.version, file, sha256: addon.sha256 }] });
}

const everyFile = (dir, under = '') => fs.readdirSync(path.join(dir, under), { withFileTypes: true }).flatMap((entry) => {
  const name = under ? `${under}/${entry.name}` : entry.name;
  return entry.isDirectory() ? everyFile(dir, name) : [name];
});

// Puts files in the addon's folder, and takes away those it no longer has (what comes in
// its Inbox stays). What was there is kept first, and put back when it fails.
function replace(wowDir, files) {
  const dir = addonDir(wowDir), before = kept(wowDir);
  if (isDevelopment(dir)) throw new Error('dev');
  fs.rmSync(before, { recursive: true, force: true });
  fs.cpSync(dir, before, { recursive: true });
  try {
    const wanted = new Set(files.map(({ name }) => name.toLowerCase()));
    for (const { name, data } of files) {
      const file = path.join(dir, name);
      if (/^Inbox\//.test(name) && fs.existsSync(file)) continue;
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, data);
    }
    for (const name of everyFile(dir)) if (!/^Inbox\//.test(name) && !wanted.has(name.toLowerCase())) fs.rmSync(path.join(dir, name));
  } catch (error) {
    fs.cpSync(before, dir, { recursive: true });
    throw error;
  }
}

export const waitingUpdates = () => readState().waiting || [];

// Installs what waits, the game closed: what was done, [{ wowDir, version, error }].
export function applyWaiting() {
  const waiting = waitingUpdates();
  if (!waiting.length || gameRunning()) return [];
  const done = waiting.map(({ wowDir, version, file, sha256 }) => {
    try {
      const zip = fs.readFileSync(file);
      if (crypto.createHash('sha256').update(zip).digest('hex') !== sha256) throw new Error('checksum');
      replace(wowDir, unzip(zip));
      return { wowDir, version };
    } catch (error) { return { wowDir, version, error: error.message }; }
  });
  writeState({ waiting: [] });
  for (const { file } of waiting) fs.rmSync(file, { force: true });
  return done;
}

// The addon as it was before its last update, the game closed.
export function undoUpdate() {
  if (gameRunning()) return { error: 'The game runs: close it first.' };
  const undone = findGames().filter((wowDir) => fs.existsSync(kept(wowDir))).map((wowDir) => {
    const before = kept(wowDir);
    const files = everyFile(before).map((name) => ({ name, data: fs.readFileSync(path.join(before, name)) }));
    replace(wowDir, files);
    return { game: wowDir, version: addonVersion(wowDir) };
  });
  return undone.length ? { undone } : { error: 'No update to undo.' };
}

// ------------------------------------------------------------- the plugin

function claude(args) {
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => key === 'CLAUDE_CONFIG_DIR' || !/^(CLAUDE|ANTHROPIC)/i.test(key)));
  const [program, ...first] = process.env.CIW_CLAUDE_TOOL ? [process.execPath, process.env.CIW_CLAUDE_TOOL] : claudeCommand();
  return new Promise((resolve) => {
    const child = spawn(program, [...first, ...args], { env, windowsHide: true, stdio: 'ignore', timeout: 180e3 });
    child.on('error', () => resolve(false));
    child.on('close', (status) => resolve(status === 0));
  });
}

// The newest version of the plugin on this computer, newer than this one: its folder.
export function newerPlugin() {
  if (!marketplace()) return null;
  const here = path.dirname(ROOT);
  const [best] = fs.readdirSync(here).filter((name) => isVersion(name) && newer(name, path.basename(ROOT))
    && fs.existsSync(path.join(here, name, 'server', 'silent-mode.mjs'))).sort((a, b) => (newer(a, b) ? -1 : 1));
  return best ? path.join(here, best) : null;
}

async function updatePlugin() {
  const from = marketplace();
  if (!from) return 'dev';
  if (!await claude(['plugin', 'marketplace', 'update', from]) || !await claude(['plugin', 'update', `wow-mcp@${from}`])) return 'failed';
  return newerPlugin() ? 'done' : 'failed';
}

// ------------------------------------------------------------- asked by the game

function openPage(url) {
  if (process.env.CIW_NO_PAGES) return;
  const [program, args] = process.platform === 'win32' ? ['rundll32', ['url.dll,FileProtocolHandler', url]] : ['open', [url]];
  try { spawn(program, args, { detached: true, stdio: 'ignore', windowsHide: true }).unref(); } catch { /* not opened */ }
}

// What the addon is told, as a text: "name=value" lines.
export function newsText(release, wowDir, states = {}) {
  const lines = ['[claude-in-wow update]', `pluginNow=${pluginVersion() || ''}`];
  const waits = waitingUpdates().find((one) => one.wowDir === wowDir);
  if (release?.addon) lines.push(`addon=${release.addon.version}`);
  if (release?.plugin) lines.push(`plugin=${release.plugin.version}`);
  if (waits) lines.push(`waits=${waits.version}`);
  for (const [name, value] of Object.entries(states)) if (value) lines.push(`${name}=${value}`);
  for (const [code, list] of Object.entries(release?.notes || {})) for (const line of list) lines.push(`notes.${code}=${line}`);
  return lines.join('\n');
}

// What is out, for the game's next login or reload.
export function tellGames(release) {
  for (const wowDir of findGames().filter(hasAddon)) {
    try { putNews(wowDir, release ? newsText(release, wowDir) : null); } catch { /* told another time */ }
  }
}

// What the player chose, as the game last saved it.
export function choices(wowDir) {
  let options = {};
  try { options = loadData(wowDir).db?.options || {}; } catch { options = {}; }
  return { mode: options.updates === 'auto' ? 'auto' : 'notify', from: options.updateFrom === 'github' ? 'github' : 'curseforge' };
}

// One update: { addon, plugin } say what was done of each (nothing: up to date).
// clicked: the player asked for it just now.
export async function update(release, wowDir, from, clicked) {
  const states = {};
  const mine = addonVersion(wowDir);
  if (release.addon && mine && newer(release.addon.version, mine)) {
    if (from !== 'github') {
      states.addonState = 'curseforge';
      if (clicked && release.curseforge) openPage(release.curseforge);
    } else if (isDevelopment(addonDir(wowDir))) {
      states.addonState = 'dev';
    } else {
      try { await stage(release.addon, wowDir); states.addonState = 'ready'; } catch (error) { states.addonState = 'failed'; states.error = error.message.slice(0, 60); }
    }
  }
  if (release.plugin && newer(release.plugin.version, pluginVersion())) {
    const { needsAddon } = release.plugin;
    if (needsAddon && mine && newer(needsAddon, mine) && states.addonState !== 'ready') states.pluginState = 'addonFirst';
    else states.pluginState = await updatePlugin();
  }
  return states;
}

// A request of the game's window ({ check } only looks): the text to give it back.
export async function answerUpdate(question, wowDir) {
  const asked = question.update || {};
  let release = null;
  try { release = await latest(true); } catch (error) { return newsText(readState().latest, wowDir, { error: error.message.slice(0, 60), checked: 'failed' }); }
  if (!release) return newsText(null, wowDir, { checked: 'none' });
  const states = asked.check ? {} : await update(release, wowDir, asked.from === 'github' ? 'github' : 'curseforge', true);
  tellGames(release);
  return newsText(release, wowDir, { checked: 'ok', ...states });
}

// Once a day: looks, tells the games, and updates by itself where the player chose so.
export async function daily(log) {
  const games = findGames().filter(hasAddon).map((wowDir) => ({ wowDir, ...choices(wowDir) }));
  if (!source()) return;
  let release = null;
  try { release = await latest(); } catch (error) { return log(`updates: ${error.message}`); }
  if (!release) return;
  for (const { wowDir, mode, from } of games) {
    if (mode === 'auto') {
      const states = await update(release, wowDir, from, false);
      if (Object.keys(states).length) log(`updates: ${JSON.stringify(states)}`);
    }
    try { putNews(wowDir, newsText(release, wowDir)); } catch { /* told another time */ }
  }
}

export { NEWS };
