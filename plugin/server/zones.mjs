// Zone names, from Questie's own lookups: Questie's database uses the game's
// old AreaTable IDs, GatherMate2 uses uiMap IDs; both turned into names here,
// the game's own when the addon saved them, else in French when Questie has the
// translation. Only the tools on the player's addons need it.

import fs from 'node:fs';
import path from 'node:path';
import { loadData } from './game.mjs';

let cache = null;

function read(file) {
  try { return fs.readFileSync(file, 'utf8'); } catch { return ''; }
}

function load(wowDir) {
  if (cache && cache.wowDir === wowDir) return cache;
  const addons = path.join(wowDir, 'Interface', 'AddOns');
  const english = new Map();
  const lookup = read(path.join(addons, 'Questie', 'Localization', 'lookups', 'lookupZones.lua'));
  const start = lookup.indexOf('l10n.zoneLookup');
  for (const m of lookup.slice(Math.max(start, 0)).matchAll(/\[(\d+)\]\s*=\s*"([^"]*)"/g)) {
    if (!english.has(Number(m[1]))) english.set(Number(m[1]), m[2]);
  }
  const categories = read(path.join(addons, 'Questie', 'Localization', 'lookups', 'lookupQuestCategories.lua'));
  for (const m of categories.matchAll(/\[(-\d+)\]\s*=\s*"([^"]*)"/g)) english.set(Number(m[1]), m[2]);

  const french = new Map(); // English name -> French name
  const translations = path.join(addons, 'Questie', 'Localization', 'Translations', 'Zones');
  let files = [];
  try { files = fs.readdirSync(translations).filter((f) => f.endsWith('.lua')); } catch { /* none */ }
  for (const file of files) {
    const text = read(path.join(translations, file));
    for (const m of text.matchAll(/\["([^"]+)"\]\s*=\s*\{([\s\S]*?)\n\s*\},?/g)) {
      const fr = /\["frFR"\]\s*=\s*\(?[^"\n]*?"([^"]+)"/.exec(m[2]);
      if (fr) french.set(m[1], fr[1]);
    }
  }

  const uiMapToArea = new Map();
  const areaToUiMap = new Map(); // the first map of an area: its main one
  const maps = read(path.join(addons, 'QuestieDB', 'support', 'Forever', 'Zones', 'uiMapIdToAreaId.lua'));
  for (const m of maps.matchAll(/\[(\d+)\]\s*=\s*(\d+)/g)) {
    if (!uiMapToArea.has(Number(m[1]))) uiMapToArea.set(Number(m[1]), Number(m[2]));
    if (!areaToUiMap.has(Number(m[2]))) areaToUiMap.set(Number(m[2]), Number(m[1]));
  }
  cache = { wowDir, english, french, uiMapToArea, areaToUiMap };
  return cache;
}

// The game's map (uiMap ID) of an AreaTable ID, for links that open the map
// in the game; undefined when Questie has none.
export function uiMapOf(wowDir, areaId) {
  return load(wowDir).areaToUiMap.get(Number(areaId));
}

// The game's own zone names the addon saved (Places.lua): uiMap ID -> name.
let own = null;
function gameNames() {
  let places;
  try { places = loadData().db?.places; } catch { places = null; }
  if (!own || own.places !== places) {
    own = { places, names: new Map((Array.isArray(places) ? places : []).filter((p) => p.kind === 'zone').map((p) => [Number(p.map), p.name])) };
  }
  return own.names;
}

// A zone's name from its AreaTable ID (or a negative quest category).
export function zoneName(wowDir, areaId) {
  const { english, french, areaToUiMap } = load(wowDir);
  const game = gameNames().get(areaToUiMap.get(Number(areaId)));
  if (game) return game;
  const en = english.get(Number(areaId));
  if (!en) return `zone ${areaId}`;
  return french.get(en) || en;
}

// A zone's name from a uiMap ID (GatherMate2, the game's map API).
export function mapName(wowDir, uiMapId) {
  const game = gameNames().get(Number(uiMapId));
  if (game) return game;
  const area = load(wowDir).uiMapToArea.get(Number(uiMapId));
  return area ? zoneName(wowDir, area) : `map ${uiMapId}`;
}
