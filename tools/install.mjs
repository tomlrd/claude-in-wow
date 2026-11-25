// Puts this copy of the addon in the games of this computer, to try it: npm run play
// Only what changed is written; what comes in its Inbox and the saved data stay. What was
// there is kept first (~/.claude-in-wow/before-play). With the game open, only what a
// /reload reads: a new file or another list of files waits for it to be closed.

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { findGames, hasAddon } from '../plugin/server/game.mjs';
import { homeDir } from '../plugin/server/home.mjs';
import { gameRunning } from '../plugin/server/updates.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const from = path.join(root, 'addon');
const all = process.argv.includes('--all'); // also where the addon is not yet
const everyFile = (dir, under = '') => fs.readdirSync(path.join(dir, under), { withFileTypes: true }).flatMap((entry) => {
  const name = under ? `${under}/${entry.name}` : entry.name;
  return entry.isDirectory() ? everyFile(dir, name) : [name];
});
const inbox = (name) => name.startsWith('Inbox/');
const same = (a, b) => fs.existsSync(b) && fs.readFileSync(a).equals(fs.readFileSync(b));
const listOf = (dir) => fs.readFileSync(path.join(dir, 'claude-in-wow.toc'), 'utf8').split(/\r?\n/).filter((line) => !line.startsWith('##')).join('\n');

execFileSync(process.execPath, [path.join(root, 'tools/inbox.mjs'), from], { stdio: 'ignore' });
const games = findGames().filter((game) => all || hasAddon(game));
if (!games.length) console.log('No game with the addon here (--all: in every game).');
let failed = false;
for (const game of games) {
  const to = path.join(game, 'Interface', 'AddOns', 'claude-in-wow');
  const there = fs.existsSync(to);
  const files = everyFile(from), wanted = new Set(files);
  const changed = files.filter((name) => (inbox(name) ? !fs.existsSync(path.join(to, name)) : !same(path.join(from, name), path.join(to, name))));
  const gone = there ? everyFile(to).filter((name) => !inbox(name) && !wanted.has(name)) : [];
  if (!changed.length && !gone.length) { console.log(`${game}: the same already`); continue; }
  if (gameRunning() && (!there || changed.some((name) => !fs.existsSync(path.join(to, name))) || listOf(from) !== listOf(to))) {
    console.log(`${game}: a new file: close the game first`);
    failed = true;
    continue;
  }
  if (there) {
    const before = path.join(homeDir(), 'before-play', path.basename(game));
    fs.rmSync(before, { recursive: true, force: true });
    fs.cpSync(to, before, { recursive: true });
  }
  for (const name of changed) {
    fs.mkdirSync(path.dirname(path.join(to, name)), { recursive: true });
    fs.copyFileSync(path.join(from, name), path.join(to, name));
  }
  for (const name of gone) fs.rmSync(path.join(to, name));
  const wrong = files.filter((name) => !inbox(name) && !same(path.join(from, name), path.join(to, name)));
  failed = failed || wrong.length > 0;
  console.log(`${game}: ${changed.length} written, ${gone.length} taken away${wrong.length ? `, NOT THE SAME: ${wrong.join(', ')}` : ''}${gameRunning() ? ': /reload' : ''}`);
}
process.exit(failed ? 1 : 0);
