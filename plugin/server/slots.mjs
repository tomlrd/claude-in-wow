// The addons loaded on demand that answers come into the game through
// (claude-in-wow_S001 and on; deliver.mjs), as many as the player picks in
// the window's settings (question.options.slots), none when the answers do not
// come by themselves. They are made here and not part of the addon as it is
// distributed: an update of the addon, which replaces its folder, leaves them
// as they are. The game finds new ones, and forgets those taken away, when it
// is next started.

import fs from 'node:fs';
import path from 'node:path';
import { languages, say } from './messages.mjs';

export const MAX_SLOTS = 200;
export const USUAL_SLOTS = 100; // the addon's default

export const EMPTY_SLOT = '-- claude-in-wow: one of Claude\'s answers on its way into the game (deliver.mjs).\n';

const padded = (slot) => String(slot).padStart(3, '0');
const slotName = (slot) => `claude-in-wow_S${padded(slot)}`;
const addons = (wowDir) => path.join(wowDir, 'Interface', 'AddOns');

export function slotFile(wowDir, slot) {
  return path.join(addons(wowDir), slotName(slot), 'Inbox.lua');
}

// The game's languages of each of ours.
const GAME = { fr: ['frFR'], de: ['deDE'], es: ['esES', 'esMX'], it: ['itIT'], pt: ['ptBR'], ru: ['ruRU'], ko: ['koKR'], zh: ['zhCN', 'zhTW'] };
const lines = (field, name, slot) => languages().flatMap((code) => (GAME[code] || []).map((game) => `## ${field}-${game}: ${say(game, name, { number: padded(slot) })}`));

const toc = (slot) => [
  '## Interface: 120105, 50504, 38002, 20506, 16001, 11509',
  `## Title: ${say('enUS', 'slotTitle', { number: padded(slot) })}`,
  ...lines('Title', 'slotTitle', slot),
  `## Notes: ${say('enUS', 'slotNotes')}`,
  ...lines('Notes', 'slotNotes', slot),
  '## Author: Stylow',
  '## Version: 1.0',
  '## LoadOnDemand: 1',
  '## Dependencies: claude-in-wow',
  '## Group: claude-in-wow',
  '## Category: Miscellaneous',
  'Inbox.lua',
  '',
].join('\n');

// A slot's folder as made here, and nothing else in it.
function isOurs(dir, slot) {
  try {
    const tocFile = path.join(dir, `${slotName(slot)}.toc`);
    return fs.lstatSync(dir).isDirectory()
      && fs.readdirSync(dir).every((name) => (name === 'Inbox.lua' || name === path.basename(tocFile)) && fs.lstatSync(path.join(dir, name)).isFile())
      && fs.readFileSync(tocFile, 'utf8').includes('\n## Group: claude-in-wow\n');
  } catch { return false; }
}

// The addon that tells the game, at each login or reload, what is out (updates.mjs): made
// like the slots, and read the same way.
export const NEWS = 'claude-in-wow_News';

export function newsFile(wowDir) {
  return path.join(addons(wowDir), NEWS, 'Inbox.lua');
}

// Writes it (null: nothing to tell). luaText: the text as the slots hold it.
export function putNews(wowDir, text, luaText = (one) => `ClaudeInWoWInbox = [==[\n${one.replaceAll(']==]', '')}\n]==]\n`) {
  if (!fs.existsSync(path.join(addons(wowDir), 'claude-in-wow', 'claude-in-wow.toc'))) return;
  const dir = path.dirname(newsFile(wowDir));
  if (!fs.existsSync(dir)) {
    if (text === null) return;
    fs.mkdirSync(dir);
    fs.writeFileSync(path.join(dir, `${NEWS}.toc`), toc('news').replace(/^## (Title|Notes)-.*\n/gm, '').replace(/^## Notes.*\n/m, '').replace(/^## Title.*$/m, '## Title: claude-in-wow: news'));
  } else if (fs.lstatSync(dir).isSymbolicLink()) return;
  const content = EMPTY_SLOT + (text === null ? '' : luaText(text));
  let there = null;
  try { there = fs.readFileSync(newsFile(wowDir), 'utf8'); } catch { there = null; }
  if (there !== content) fs.writeFileSync(newsFile(wowDir), content);
}

// Makes the slots that are missing and takes away those over the number:
// { made, removed }.
// How many there are.
export function slotsThere(wowDir) {
  let count = 0;
  for (let slot = 1; slot <= MAX_SLOTS; slot += 1) if (fs.existsSync(path.join(addons(wowDir), slotName(slot)))) count += 1;
  return count;
}

export function setSlots(wowDir, count) {
  const done = { made: 0, removed: 0 };
  if (!wowDir || !Number.isInteger(count) || count < 0 || count > MAX_SLOTS) return done;
  if (!fs.existsSync(path.join(addons(wowDir), 'claude-in-wow', 'claude-in-wow.toc'))) return done;
  for (let slot = 1; slot <= MAX_SLOTS; slot += 1) {
    const dir = path.join(addons(wowDir), slotName(slot));
    const there = fs.existsSync(dir);
    if (slot <= count && !there) {
      fs.mkdirSync(dir);
      fs.writeFileSync(path.join(dir, `${slotName(slot)}.toc`), toc(slot));
      fs.writeFileSync(path.join(dir, 'Inbox.lua'), EMPTY_SLOT);
      done.made += 1;
    } else if (slot > count && there && isOurs(dir, slot)) {
      for (const name of fs.readdirSync(dir)) fs.unlinkSync(path.join(dir, name));
      fs.rmdirSync(dir);
      done.removed += 1;
    }
  }
  return done;
}
