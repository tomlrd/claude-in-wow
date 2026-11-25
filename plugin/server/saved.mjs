// SavedVariables files read once and kept until the game rewrites them.

import fs from 'node:fs';
import { parseSavedVariables } from './savedvars.mjs';

const parsed = new Map(); // file -> { mtimeMs, globals }

export function readSaved(file) {
  const stat = fs.statSync(file);
  const known = parsed.get(file);
  if (known && known.mtimeMs === stat.mtimeMs) return known;
  const entry = { mtimeMs: stat.mtimeMs, globals: parseSavedVariables(fs.readFileSync(file)) };
  parsed.set(file, entry);
  return entry;
}
