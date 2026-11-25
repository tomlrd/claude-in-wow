// Where the game is, and the claude-in-wow data the game writes at every
// reload or logout.

import fs from 'node:fs';
import path from 'node:path';
import { homeDir } from './home.mjs';
import { isPhotoFile, newestPhoto, withPhoto } from './photo.mjs';
import { parseSavedVariables } from './savedvars.mjs';

const ADDON_FILE = 'claude-in-wow.lua';
const GLOBAL = 'ClaudeInWoWDB';

// The games installed (Retail, the Classic ones, Forever, test realms), each a
// folder with its own addons and saved data. CIW_WOW_DIR (or WOW_DIR): that one
// alone; CIW_WOW_ROOT: a World of Warcraft folder to look in; else where the player
// said it is, where Battle.net says it installed it, and the usual places on every drive.
export function findGames() {
  for (const name of ['CIW_WOW_DIR', 'WOW_DIR']) {
    const dir = process.env[name];
    if (dir && fs.existsSync(path.join(dir, 'WTF'))) return [dir];
  }
  const roots = process.env.CIW_WOW_ROOT ? [process.env.CIW_WOW_ROOT] : [...chosenRoots(), ...battleNetRoots(), ...usualRoots()];
  const seen = new Set();
  return roots.flatMap(gamesIn).filter((dir) => {
    const same = path.resolve(dir).toLowerCase();
    return !seen.has(same) && seen.add(same);
  });
}

// The games of a folder: those in it, or itself when it is one's.
function gamesIn(folder) {
  if (fs.existsSync(path.join(folder, 'WTF'))) return [folder];
  return safeList(folder).filter((name) => /^_\w+_$/.test(name) && fs.existsSync(path.join(folder, name, 'WTF'))).map((name) => path.join(folder, name));
}

// Where the player said the game is, kept for the next time.
const config = () => path.join(homeDir(), 'config.json');

function readConfig() {
  try { return JSON.parse(fs.readFileSync(config(), 'utf8')) || {}; } catch { return {}; }
}

function chosenRoots() {
  const { games } = readConfig();
  return Array.isArray(games) ? games.filter((folder) => typeof folder === 'string') : [];
}

export function chooseGame(folder) {
  const games = folder ? gamesIn(path.resolve(String(folder))) : [];
  if (!games.length) return { error: `No game in ${folder}: give the World of Warcraft folder, or a version's (such as _retail_), once the game has been started.` };
  fs.mkdirSync(homeDir(), { recursive: true });
  fs.writeFileSync(config(), JSON.stringify({ ...readConfig(), games: [...new Set([path.resolve(String(folder)), ...chosenRoots()])] }, null, 1));
  return { games };
}

// Where Battle.net says it installed the game: the folders named in its list of products
// (only they are looked for in it), wherever the player put them.
let installed = null;
function battleNetRoots() {
  if (installed) return installed;
  const file = process.env.CIW_PRODUCT_DB || (process.platform === 'win32'
    ? path.join(process.env.ProgramData || 'C:\\ProgramData', 'Battle.net', 'Agent', 'product.db') : '/Users/Shared/Battle.net/Agent/product.db');
  let text = '';
  try { text = fs.readFileSync(file, 'utf8'); } catch { /* no Battle.net */ }
  const found = text.match(process.platform === 'win32' ? /[A-Za-z]:[\\/][^\x00-\x1f"<>|?*:]+/g : /\/(?:Applications|Users|Volumes)\/[^\x00-\x1f"<>|?*:]+/g) || [];
  // what follows a path in the file may be a letter: then without it
  installed = [...new Set(found.flatMap((one) => [one, one.slice(0, -1), one.slice(0, -2)].find((folder) => gamesIn(folder).length) || []))];
  return installed;
}

let roots = null;
function usualRoots() {
  if (roots) return roots;
  roots = [];
  if (process.platform === 'win32') {
    for (const drive of 'CDEFGHIJKLMNOPQRSTUVWXYZ') {
      for (const base of ['', 'Program Files (x86)', 'Program Files', 'Games', 'Jeux']) roots.push(path.join(`${drive}:\\`, base, 'World of Warcraft'));
    }
  } else {
    roots.push('/Applications/World of Warcraft');
  }
  roots = roots.filter((root) => fs.existsSync(root));
  return roots;
}

// Whether the addon is installed in a game.
export function hasAddon(wowDir) {
  return fs.existsSync(path.join(wowDir, 'Interface', 'AddOns', 'claude-in-wow', 'claude-in-wow.toc'));
}

// The games to serve: those with the addon, or all when none has it yet.
export function servedGames() {
  const games = findGames();
  return games.some(hasAddon) ? games.filter(hasAddon) : games;
}

// The one played last: by its saved data and its screenshots (a photo is one).
export function findWowDir() {
  const games = servedGames();
  if (games.length < 2) return games[0] || null;
  const played = (dir) => Math.max(findSavedVariables(dir)?.mtimeMs || 0, safeStat(screenshotsDir(dir))?.mtimeMs || 0);
  return games.map((dir) => ({ dir, at: played(dir) })).sort((a, b) => b.at - a.at)[0].dir;
}

// The newest claude-in-wow.lua among the game's accounts.
export function findSavedVariables(wowDir) {
  const accounts = path.join(wowDir, 'WTF', 'Account');
  let best = null;
  for (const account of safeList(accounts)) {
    const file = path.join(accounts, account, 'SavedVariables', ADDON_FILE);
    const stat = safeStat(file);
    if (stat && (!best || stat.mtimeMs > best.mtimeMs)) best = { file, mtimeMs: stat.mtimeMs, account };
  }
  return best;
}

function safeList(dir) {
  try { return fs.readdirSync(dir); } catch { return []; }
}

function safeStat(file) {
  try { return fs.statSync(file); } catch { return null; }
}

const caches = new Map(); // game -> its saved data, as last read

// { wowDir, file, db, photo } (db empty without the addon's data) or { error }.
// A photo newer than the snapshot (photo.mjs) stands in for its character.
export function loadData(wowDir = findWowDir()) {
  const data = loadSnapshot(wowDir);
  if (data.error || data.noCompanion) return data;
  const photo = newestPhoto(screenshotsDir(data.wowDir), (key) => data.db.characters?.[key]?.savedAt);
  if (!photo) return data;
  return { ...data, db: withPhoto(data.db, photo), photo: { files: photo.files, savedAt: photo.savedAt } };
}

function loadSnapshot(wowDir) {
  if (!wowDir) {
    return { error: 'World of Warcraft was not found. Ask the player where its folder is, and call silent_mode with action "game" and that folder (or set CIW_WOW_DIR to the version\'s, such as _retail_).' };
  }

  const found = findSavedVariables(wowDir);
  if (!found) return { wowDir, db: {}, noCompanion: true };
  const cached = caches.get(wowDir);
  if (cached && cached.file === found.file && cached.mtimeMs === found.mtimeMs) return cached;
  const globals = parseSavedVariables(fs.readFileSync(found.file));
  caches.set(wowDir, { ...found, wowDir, db: globals[GLOBAL] || {} });
  return caches.get(wowDir);
}

export const NO_COMPANION = 'No claude-in-wow data yet: install the claude-in-wow addon, then reload or log out once in game (it notes the game state then).';

// Characters, newest snapshot first: [{ key, data }].
export function characters(db) {
  return Object.entries(db.characters || {})
    .map(([key, data]) => ({ key, data }))
    .sort((a, b) => (b.data.savedAt || 0) - (a.data.savedAt || 0));
}

// The character asked for (part of its name), else the newest snapshot.
export function pickCharacter(db, query) {
  const list = characters(db);
  if (!query) return list[0] || null;
  const q = fold(query);
  return list.find((c) => fold(c.key) === q) || list.find((c) => fold(c.key).includes(q)) || null;
}

// The quests a character has handed in, as the game says (the addon notes them at
// a reload or a logout); null when it has not noted them.
export function questsDone(char) {
  return typeof char?.questsDone === 'string' ? new Set(char.questsDone.split(' ').filter(Boolean).map(Number)) : null;
}

// Every item the snapshots noted (bags, bank, equipment, account bank), by
// ID: { item } as first met (name in the game's language, tooltip texts) and
// where each character has it.
export function notedItems(db) {
  const found = new Map();
  const add = (owner, place, id, item) => {
    if (!id || !item) return;
    let entry = found.get(Number(id));
    if (!entry) found.set(Number(id), (entry = { item, places: [] }));
    entry.places.push(`${owner}: ${place}${item.count > 1 ? ` x${item.count}` : ''}`);
  };
  for (const { key, data: char } of characters(db)) {
    for (const [id, item] of Object.entries(char.bags?.items || {})) add(key, 'bags', id, item);
    for (const [id, item] of Object.entries(char.bank?.items || {})) add(key, 'bank', id, item);
    for (const [slot, item] of Object.entries(char.equipment || {})) add(key, `equipped (${slot})`, item?.id, item);
  }
  for (const [id, item] of Object.entries(db.warbandBank?.items || {})) add('account', 'account bank', id, item);
  return found;
}

// Lower case without accents, for searches.
export function fold(text) {
  return String(text ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

export function screenshotsDir(wowDir) {
  return path.join(wowDir, 'Screenshots');
}

export function listScreenshots(wowDir, count) {
  const dir = screenshotsDir(wowDir);
  return safeList(dir)
    .filter((name) => /\.(jpe?g|png|tga)$/i.test(name))
    .map((name) => {
      const file = path.join(dir, name);
      const stat = safeStat(file);
      return stat && !isPhotoFile(file) && { file, mtimeMs: stat.mtimeMs, size: stat.size };
    })
    .filter(Boolean)
    .sort((a, b) => b.mtimeMs - a.mtimeMs)
    .slice(0, count);
}
