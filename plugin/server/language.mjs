// The language Claude speaks with the player ("fr"): the one set in Claude Code
// ("language" of its settings), else the computer's. The addon may show its window in it.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

// The languages by the names people give them.
const NAMES = {
  en: ['english', 'anglais'], fr: ['french', 'français', 'francais'], de: ['german', 'deutsch', 'allemand'], es: ['spanish', 'español', 'espanol', 'espagnol'],
  it: ['italian', 'italiano', 'italien'], pt: ['portuguese', 'português', 'portugues', 'portugais'], ru: ['russian', 'русский', 'russe'], ko: ['korean', '한국어', 'coréen'],
  zh: ['chinese', '中文', 'chinois'], ja: ['japanese', '日本語', 'japonais'],
};

export function languageCode(name) {
  const said = String(name || '').trim().toLowerCase();
  const code = /^([a-z]{2})([-_]|$)/.exec(said)?.[1];
  return code || Object.keys(NAMES).find((key) => NAMES[key].some((word) => said.startsWith(word))) || null;
}

export function claudeLanguage() {
  let set = null;
  try { set = JSON.parse(fs.readFileSync(path.join(process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude'), 'settings.json'), 'utf8')).language; } catch { set = null; }
  return languageCode(set) || languageCode(Intl.DateTimeFormat().resolvedOptions().locale);
}
