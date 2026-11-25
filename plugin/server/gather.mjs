// The gathering nodes the player's GatherMate2 has recorded (its saved data),
// with node names from GatherMate2's own files, in French when it has them.
// GatherMate2<Kind>DB = { [uiMapID] = { [coordKey] = nodeID } } where
// x = floor(key / 1e6) / 1e4 and y = floor(key % 1e6 / 100) / 1e4 (0-1).

import fs from 'node:fs';
import path from 'node:path';

export const KINDS = {
  GatherMate2MineDB: 'Mining',
  GatherMate2HerbDB: 'Herb Gathering',
  GatherMate2FishDB: 'Fishing',
  GatherMate2GasDB: 'Extract Gas',
  GatherMate2TreasureDB: 'Treasure',
  GatherMate2ArchaeologyDB: 'Archaeology',
  GatherMate2LoggingDB: 'Logging',
};

let names = null;

function read(file) {
  try { return fs.readFileSync(file, 'utf8'); } catch { return ''; }
}

// { "Mining": Map(nodeID -> name) }
export function nodeNames(wowDir) {
  if (names && names.wowDir === wowDir) return names.byKind;
  const folder = path.join(wowDir, 'Interface', 'AddOns', 'GatherMate2');
  const french = new Map();
  for (const file of [path.join(folder, 'Locales', 'GatherMate2-frFR.lua'), path.join(folder, 'Locales', 'Vanilla', 'GatherMate2-Vanilla-frFR.lua')]) {
    for (const m of read(file).matchAll(/^\s*NLV?\["([^"]+)"\]\s*=\s*"([^"]*)"/gm)) french.set(m[1], m[2]);
  }

  // node_ids: a tab-indented table of kinds, each of ["Name"] = id or
  // ["Name"] = { id = N, variants = {...} }.
  const constants = read(path.join(folder, 'Constants.lua'));
  const lines = constants.slice(Math.max(constants.indexOf('local node_ids'), 0)).split(/\r?\n/).slice(1);
  const byKind = {};
  let kind = null;
  let pending = null;
  const add = (name, id) => {
    if (kind && !byKind[kind].has(id)) byKind[kind].set(id, french.get(name) || name);
  };
  for (const raw of lines) {
    if (/^\}/.test(raw)) break; // the end of node_ids
    const depth = /^\t*/.exec(raw)[0].length;
    const line = raw.trim();
    if (!line || line.startsWith('--')) continue;
    const named = /^\["([^"]+)"\]\s*=\s*(\{|\d+)/.exec(line);
    if (depth === 1 && named) { kind = named[1]; byKind[kind] ??= new Map(); continue; }
    if (depth === 2 && named) {
      if (named[2] === '{') pending = named[1];
      else add(named[1], Number(named[2]));
      continue;
    }
    const id = /^id\s*=\s*(\d+)/.exec(line);
    if (id && pending) { add(pending, Number(id[1])); pending = null; }
  }
  names = { wowDir, byKind };
  return byKind;
}

// A coordinate key as map percents.
export function decodeCoord(key) {
  const k = Number(key);
  return { x: Math.floor(k / 1e6) / 100, y: Math.floor((k % 1e6) / 100) / 100 };
}
