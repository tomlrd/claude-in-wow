// The game's functions that only read, with their arguments and what they give
// (data/functions.json, made from Blizzard's documentation by
// tools/functions.mjs): finding those a question proposed to the player can have
// read. The addon has the same list, and calls nothing else.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const file = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'data', 'functions.json');
let loaded = null;

function data() {
  loaded ??= JSON.parse(fs.readFileSync(file, 'utf8'));
  return loaded;
}

// "C_A.Get(x:number) -> info:Info", with the fields of the structures it gives.
function describe(name) {
  const known = data().functions[name];
  if (!known) return { function: `${name}(...)`, note: 'not documented: called as in other versions of the game' };
  const [args, gives] = known;
  const structures = {};
  for (const [, kind] of gives.matchAll(/:([A-Za-z0-9_]+)/g)) if (data().structures[kind]) structures[kind] = data().structures[kind];
  return { function: `${name}(${args})`, gives: gives || undefined, structures: Object.keys(structures).length ? structures : undefined };
}

// The functions whose name, arguments or results hold every word, names first.
export function findFunctions(search, limit = 25) {
  const words = String(search || '').toLowerCase().split(/[^a-z0-9_.]+/).filter(Boolean);
  if (!words.length) return { error: 'Words to look for, in English, e.g. "guild member" or "C_TradeSkillUI recipe".' };
  const scored = [];
  for (const [name, known] of Object.entries(data().functions)) {
    const own = name.toLowerCase();
    const all = `${own} ${(known || []).join(' ').toLowerCase()}`;
    if (!words.every((word) => all.includes(word))) continue;
    scored.push({ name, score: words.filter((word) => own.includes(word)).length * 100 - name.length });
  }
  scored.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name));
  return { found: scored.length, functions: scored.slice(0, limit).map(({ name }) => describe(name)) };
}
