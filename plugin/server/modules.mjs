// The modules, on Claude's side: small files that tell it what the addon's
// window does with its answers (modules/*.md, described in modules/README.md).
// A "modules" folder in the folder Claude works in replaces those of the same
// name and adds its own. Together they are what Claude is told at the start of
// a session of the silent mode.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { flavorOf } from './flavors.mjs';
import { findWowDir } from './game.mjs';

export const MODULES_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'modules');
const MAX_PLACES = 400;

function filesIn(dir) {
  let names = [];
  try { names = fs.readdirSync(dir); } catch { return []; }
  return names.filter((name) => name.endsWith('.md') && name !== 'README.md').map((name) => ({ name, file: path.join(dir, name) }));
}

// "---" lines around "key: value" ones, then the text.
function parse(name, text) {
  const head = /^---\r?\n([\s\S]*?)\r?\n---\r?\n/.exec(text);
  const meta = Object.fromEntries((head ? head[1] : '').split(/\r?\n/).map((line) => line.split(/:\s*/, 2)).filter(([key, value]) => key && value));
  const sites = (meta.sites || '').split(/[\s,]+/).filter((site) => /^[\w.-]+\.[a-z]+$/i.test(site));
  return { name, key: meta.key || name.replace(/^\d+-|\.md$/g, ''), title: meta.title || name, sites, text: (head ? text.slice(head[0].length) : text).trim() };
}

// The modules, in the order of their names: { name, key, title, sites, text }.
export function loadModules(dir) {
  const files = new Map();
  for (const { name, file } of [...filesIn(MODULES_DIR), ...(dir ? filesIn(path.join(dir, 'modules')) : [])]) files.set(name, file);
  return [...files].sort(([a], [b]) => a.localeCompare(b)).map(([name, file]) => parse(name, fs.readFileSync(file, 'utf8')));
}

// The place names of the player's game, as the addon saved them: "Name=map".
function placeNames(db) {
  const places = Array.isArray(db?.places) ? db.places : [];
  if (!places.length) return 'The game has not told its place names yet.';
  return `Place names of this game, with their map's number: ${places.slice(0, MAX_PLACES).map(({ name, map }) => `${name}=${map}`).join(', ')}.`;
}

// The addons of the player that hold data of their own, with the tools that read
// it: Claude needs none, the player may ask about them.
const DATA_ADDONS = [
  { folder: 'QuestieDB', says: 'Questie, quests, creatures and items (quest_info, npc_info, item_info)' },
  { folder: 'GatherMate2', says: 'GatherMate2, gathering nodes seen (gathering)' },
  { folder: 'TradeSkillMaster_AppHelper', says: 'TradeSkillMaster, auction house prices (prices)' },
];
function dataAddons(dir) {
  const here = DATA_ADDONS.filter(({ folder }) => dir && fs.existsSync(path.join(dir, 'Interface', 'AddOns', folder)));
  return here.length ? here.map(({ says }) => says).join('; ') : 'none';
}

// The tools that read the player's addons: refused when the player limits them
// (silent.mjs tells the server by an environment variable).
export const ADDON_TOOL_NAMES = new Set(['quest_info', 'npc_info', 'item_info', 'gathering', 'prices', 'saved_variables', 'addons']);
export const ADDONS_ENV = 'CIW_ADDONS';

// The sites Claude may read when the chat of other players is in its session.
export function webSites(dir) {
  return loadModules(dir).flatMap((module) => module.sites);
}

// What Claude is told at the start of a session, for a game.
export function systemPrompt(dir, db, wowDir = findWowDir()) {
  const flavor = flavorOf(wowDir, db);
  const language = { fr: '/fr', de: '/de', es: '/es', pt: '/pt', it: '/it', ru: '/ru', ko: '/ko', zh: '/cn' }[String(db?.game?.locale || 'enUS').slice(0, 2)] || '';
  return loadModules(dir).map(({ title, text }) => `# ${title}\n\n${text.replace('{{places}}', placeNames(db)).replace('{{addons}}', dataAddons(wowDir)).replace('{{sites}}', webSites(dir).join(', ')).replaceAll('{{game}}', wowDir || 'unknown')
    .replaceAll('{{title}}', flavor.title).replaceAll('{{about}}', flavor.about).replaceAll('{{search}}', flavor.search).replaceAll('{{wowhead}}', `www.wowhead.com${flavor.wowhead[0]}${language}`)}`).join('\n\n');
}
