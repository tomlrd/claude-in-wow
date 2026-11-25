// The addons installed in the game: read from their .toc files, whether each
// is enabled from the character's AddOns.txt, and their saved data files.

import fs from 'node:fs';
import path from 'node:path';
import { flavorOf } from './flavors.mjs';

// A version loads its own .toc first (flavors.mjs), then the plain one.

function safeList(dir) {
  try { return fs.readdirSync(dir); } catch { return []; }
}

// Colour codes and textures out of a .toc text.
function plain(text) {
  return String(text ?? '')
    .replace(/\|c[0-9a-fA-F]{8}/g, '').replace(/\|c[nN][^:]*:/g, '').replace(/\|r/g, '')
    .replace(/\|T.*?\|t/g, '').replace(/\|A.*?\|a/g, '').trim();
}

function readToc(folder, name, suffixes) {
  for (const suffix of suffixes) {
    const file = path.join(folder, `${name}${suffix}.toc`);
    let text;
    try { text = fs.readFileSync(file, 'utf8'); } catch { continue; }
    const meta = {};
    const files = [];
    for (const raw of text.replace(/^﻿/, '').split(/\r?\n/)) {
      const line = raw.trim();
      const tag = /^##\s*([^:]+?)\s*:\s*(.*)$/.exec(line);
      if (tag) meta[tag[1].toLowerCase()] = tag[2];
      else if (line && !line.startsWith('#')) files.push(line);
    }
    return { file, meta, files };
  }
  return null;
}

const list = (value) => (value ? value.split(',').map((s) => s.trim()).filter(Boolean) : []);

// Every addon folder with a .toc the game would read.
export function installedAddons(wowDir, locale = 'frFR') {
  const root = path.join(wowDir, 'Interface', 'AddOns');
  const suffixes = [...flavorOf(wowDir).tocs, ''];
  const out = [];
  for (const name of safeList(root)) {
    if (/^claude-in-wow_S\d+$/.test(name)) continue; // where answers come into the game (deliver.mjs)
    const toc = readToc(path.join(root, name), name, suffixes);
    if (!toc) continue;
    const m = toc.meta;
    out.push({
      name,
      title: plain(m[`title-${locale.toLowerCase()}`] || m.title || name),
      notes: plain(m[`notes-${locale.toLowerCase()}`] || m.notes) || undefined,
      version: m.version,
      author: plain(m.author) || undefined,
      interface: m.interface,
      dependencies: list(m.dependencies || m.requireddeps || m.dep),
      optionalDependencies: list(m.optionaldeps),
      loadOnDemand: m.loadondemand === '1' || undefined,
      savedVariables: list(m.savedvariables),
      savedVariablesPerCharacter: list(m.savedvariablespercharacter),
      folder: path.join(root, name),
      toc: toc.file,
    });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

// The game's accounts and characters: WTF\Account\<account>\<realm>\<character>.
export function accounts(wowDir) {
  const root = path.join(wowDir, 'WTF', 'Account');
  return safeList(root)
    .filter((account) => fs.existsSync(path.join(root, account, 'SavedVariables')))
    .map((account) => {
      const characters = [];
      for (const realm of safeList(path.join(root, account))) {
        const realmDir = path.join(root, account, realm);
        if (realm === 'SavedVariables' || !fs.statSync(realmDir).isDirectory()) continue;
        for (const character of safeList(realmDir)) {
          const dir = path.join(realmDir, character);
          if (fs.existsSync(path.join(dir, 'AddOns.txt')) || fs.existsSync(path.join(dir, 'SavedVariables'))) {
            characters.push({ realm, name: character, dir });
          }
        }
      }
      return { account, dir: path.join(root, account), characters };
    });
}

// The character's folder from a name ("Arden Valcourt", "arden"), else the one
// played last.
export function characterFolder(wowDir, query) {
  const all = accounts(wowDir).flatMap((a) => a.characters.map((c) => ({ ...c, account: a.account, accountDir: a.dir })));
  if (!all.length) return null;
  if (query) {
    const q = String(query).toLowerCase().replace(/[\s-]+/g, '-');
    const found = all.find((c) => c.name.toLowerCase() === q) || all.find((c) => c.name.toLowerCase().includes(q));
    if (found) return found;
  }
  const mtime = (c) => {
    try { return fs.statSync(path.join(c.dir, 'AddOns.txt')).mtimeMs; } catch { return 0; }
  };
  return all.sort((a, b) => mtime(b) - mtime(a))[0];
}

// { addonName: true/false } from the character's AddOns.txt.
export function enabledAddons(characterDir) {
  const enabled = {};
  let text = '';
  try { text = fs.readFileSync(path.join(characterDir, 'AddOns.txt'), 'utf8'); } catch { return enabled; }
  for (const line of text.split(/\r?\n/)) {
    const m = /^(.+?):\s*(enabled|disabled)\s*$/i.exec(line.trim());
    if (m) enabled[m[1]] = m[2].toLowerCase() === 'enabled';
  }
  return enabled;
}

// The saved data files of an addon: account-wide and for the character.
export function savedVariablesFiles(wowDir, addonName, character) {
  const files = [];
  for (const account of accounts(wowDir)) {
    const accountFile = path.join(account.dir, 'SavedVariables', `${addonName}.lua`);
    if (fs.existsSync(accountFile)) files.push({ scope: 'account', account: account.account, file: accountFile });
  }
  if (character) {
    const charFile = path.join(character.dir, 'SavedVariables', `${addonName}.lua`);
    if (fs.existsSync(charFile)) files.push({ scope: 'character', character: character.name, file: charFile });
  }
  return files;
}
