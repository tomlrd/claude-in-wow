// What the plugin itself says in the game: in the game's language, in English where it
// has none. Each language is a file of locales, by its two letters (see the addon's
// TRANSLATING.md); a text a language lacks is the English one.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const folder = path.join(path.dirname(fileURLToPath(import.meta.url)), 'locales');
const read = (code) => {
  try { return JSON.parse(fs.readFileSync(path.join(folder, `${code}.json`), 'utf8')); } catch { return {}; }
};
const ENGLISH = read('en');
const known = new Map();

// The languages there are, English apart.
export function languages() {
  return fs.readdirSync(folder).map((name) => /^([a-z]{2})\.json$/.exec(name)?.[1]).filter((code) => code && code !== 'en').sort();
}

// A text in a game's language ("frFR", "esMX"), its {parts} filled.
export function say(locale, name, parts = {}) {
  const code = String(locale || 'en').slice(0, 2).toLowerCase();
  if (!known.has(code)) known.set(code, /^[a-z]{2}$/.test(code) ? read(code) : {});
  const text = known.get(code)[name] ?? ENGLISH[name] ?? name;
  return text.replace(/\{(\w+)\}/g, (whole, part) => parts[part] ?? whole);
}

// Why Claude gave no answer, from what it said.
export function failureKind(error) {
  const text = String(error || '');
  if (/ENOENT/.test(text)) return 'notFound';
  if (/authenticat|not logged in|log ?in|oauth|api key/i.test(text)) return 'signIn';
  if (/limit|quota|out of .*usage/i.test(text)) return 'limit';
  if (/no answer in time/i.test(text)) return 'late';
  return 'other';
}

export function failureText(error, locale) {
  const kind = failureKind(error);
  const why = say(locale, kind, { error: String(error || '?').replace(/[.\s]+$/, '') });
  return `*${say(locale, 'failed', { why })}*\n\n${say(locale, `${kind}Fix`)}`;
}
