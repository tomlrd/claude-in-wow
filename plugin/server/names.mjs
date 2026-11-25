// The game's numbers for names, from Wowhead's search (the database of the version
// played, in English and in the client's language): for the items, quests, creatures and characters of an
// answer to be links, with the game's own tooltips. What is found is kept in a
// file, so a name is asked once.

import fs from 'node:fs';
import path from 'node:path';
import { flavorOf, wowheadSites } from './flavors.mjs';
import { findWowDir, fold, loadData } from './game.mjs';
import { dataDir } from './home.mjs';

const TYPES = { 1: 'npc', 3: 'item', 5: 'quest' };
const MOST = 12;          // names looked up at a time
const WAIT_MS = 4000;     // for one search
const ALL_MS = 8000;      // for all of an answer's
const AT_ONCE = 3;        // names looked up together
const AGAIN_S = 7 * 86400; // a name not found is asked again after that

const file = () => path.join(dataDir(), 'claude-in-wow-names.json');
let known = null; // version:folded name -> { type, id, name, at } (no id: not found)

// Where to search for a game: { key, sites }.
export function placesToSearch(wowDir = findWowDir()) {
  let db = null;
  try { db = loadData(wowDir).db; } catch { db = null; }
  const flavor = flavorOf(wowDir, db);
  return { key: flavor.key, sites: wowheadSites(flavor, db?.game?.locale || 'frFR') };
}

function load() {
  if (!known) {
    try { known = new Map(Object.entries(JSON.parse(fs.readFileSync(file(), 'utf8')))); } catch { known = new Map(); }
  }
  return known;
}

// One site's search: what has exactly that name, { type, id, name }.
async function search(site, name) {
  const response = await fetch(`${site}/search/suggestions-template?q=${encodeURIComponent(name)}`, { signal: AbortSignal.timeout(WAIT_MS), headers: { accept: 'application/json' } });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const { results } = await response.json();
  const same = (results || []).filter((r) => TYPES[r.type] && fold(r.name) === fold(name));
  const found = same.find((r) => r.type === 3) || same[0];
  return found ? { type: TYPES[found.type], id: Number(found.id), name: found.name } : null;
}

// What names are: name -> { type, id, name } for those found.
export async function numbers(names, look = search, where = placesToSearch()) {
  const cache = load();
  const at = (name) => `${where.key}:${fold(name)}`;
  const now = Math.floor(Date.now() / 1000);
  const wanted = [...new Set(names.map((name) => String(name).trim()).filter(Boolean))];
  const unknown = wanted.filter((name) => {
    const entry = cache.get(at(name));
    return !entry || !entry.id && now - entry.at > AGAIN_S;
  }).slice(0, MOST);
  const until = Date.now() + ALL_MS;
  const one = async (name) => {
    let found = null, sure = true;
    for (const sites of where.sites) {
      const answers = await Promise.allSettled(sites.map((site) => look(site, name)));
      found = answers.map((a) => a.value).find(Boolean);
      sure = sure && answers.every((a) => a.status === 'fulfilled');
      if (found) break;
    }
    if (found) cache.set(at(name), { ...found, at: now });
    else if (sure) cache.set(at(name), { at: now });
  };
  const queue = [...unknown];
  await Promise.all([...Array(AT_ONCE)].map(async () => {
    while (queue.length && Date.now() < until) await one(queue.shift());
  }));
  if (unknown.length) {
    try { fs.writeFileSync(file(), JSON.stringify(Object.fromEntries(cache))); } catch { /* not kept */ }
  }
  return new Map(wanted.map((name) => [name, cache.get(at(name))]).filter(([, entry]) => entry?.id));
}

// An answer's names in bold that are no link yet, made links: those the search
// knows, of at most these words, but never a name in leave (players, guilds,
// places: they are not looked up).
const BOLD = /\*\*([^*\n[\]()`|:]{4,60})\*\*/g;

export async function linkNames(text, leave = new Set(), look = search, where = placesToSearch()) {
  const outside = text.split(/(```[\s\S]*?(?:```|$))/); // code blocks: every other part
  const names = new Set();
  outside.forEach((part, i) => {
    if (i % 2) return;
    for (const [, name] of part.matchAll(BOLD)) if (/\p{Lu}/u.test(name) && !leave.has(fold(name))) names.add(name.trim());
  });
  const found = names.size ? await numbers([...names], look, where) : new Map();
  const bold = outside.map((part, i) => (i % 2 ? part : part.replace(BOLD, (whole, name) => {
    const entry = found.get(name.trim());
    return entry ? `**[${name.trim()}](${entry.type}:${entry.id})**` : whole;
  })));
  return linkKnown(bold, leave, where.key);
}

// The names already found, for this answer (the numbers tool) or an earlier one:
// each one's first mention made a link, where it is none yet.
function linkKnown(parts, leave, version) {
  const entries = [...load()].filter(([key]) => key.startsWith(`${version}:`)).map(([, entry]) => entry).filter(({ id, name }) => id && name && name.length >= 5 && /^\p{Lu}/u.test(name) && !leave.has(fold(name)))
    .sort((a, b) => b.name.length - a.name.length);
  const all = parts.join('');
  for (const { type, id, name } of entries) {
    if (!all.includes(name) || all.includes(`(${type}:${id})`)) continue;
    const mention = new RegExp(`(?<![\\p{L}\\p{N}])${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?![\\p{L}\\p{N}])`, 'u');
    let done = false;
    for (let i = 0; i < parts.length && !done; i += 2) {
      const pieces = parts[i].split(/(\[[^\]\n]*\]\([^)\n]*\)|`[^`\n]*`)/); // links and code: every other piece
      for (let k = 0; k < pieces.length && !done; k += 2) {
        if (!mention.test(pieces[k])) continue;
        pieces[k] = pieces[k].replace(mention, () => `[${name}](${type}:${id})`);
        done = true;
      }
      parts[i] = pieces.join('');
    }
  }
  return parts.join('');
}

// The names of people and guilds in what was read for a question, folded.
export function people(read, into = new Set()) {
  if (Array.isArray(read)) read.forEach((item) => people(item, into));
  else if (read && typeof read === 'object') {
    for (const [key, value] of Object.entries(read)) {
      if (typeof value === 'string') {
        if (/^(name|who|player|leader|author|guild|note|rank)$/i.test(key)) into.add(fold(value));
      } else people(value, into);
    }
  }
  return into;
}
