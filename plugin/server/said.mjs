// What the player says in a Claude session they see, not from the game (typed or dictated
// there), shown in the game's window with its answer. The game sets a few places apart for
// it (the addon's Inbox.lua): a signal and a slot each, taken in order, as told by its
// newest photo or its saved data. Each is used once; the addon gives others with the
// player's next question or photo.

import fs from 'node:fs';
import path from 'node:path';
import { answerMark } from './clipboard.mjs';
import { channelOf, deliver } from './deliver.mjs';
import { findGames, loadData, screenshotsDir } from './game.mjs';
import { newestSpare } from './photo.mjs';
import { silentFiles } from './silent-mode.mjs';

const MAX_ASKED = 4000; // characters
const SAME_S = 60;      // a place taken so long before the game told it again was on its way

const usedFile = () => path.join(path.dirname(silentFiles().state), 'claude-in-wow-said.json');

function readUsed() {
  try { return JSON.parse(fs.readFileSync(usedFile(), 'utf8')).filter((used) => Number.isFinite(used?.at)); } catch { return []; }
}

// The places of a game: { at, list }, or null.
function spareOf(wowDir) {
  let saved = null, seen = null; // the photo first: reading the saved data deletes those it replaces
  try { seen = newestSpare(screenshotsDir(wowDir)); } catch { seen = null; }
  try { saved = loadData(wowDir).db?.spare || null; } catch { saved = null; }
  return (seen?.at || 0) >= (saved?.at || 0) ? seen : saved;
}

// The text as the window takes it, pasted or come by itself.
export function saidText(at, asked, answer) {
  return `[claude-in-wow dit ${at}]\n\n${String(asked).trim().slice(0, MAX_ASKED)}\n\n${answerMark(at)}\n\n${answer}`;
}

// Puts it in the game: { text, delivered, left } (left: places after this one).
export function say(asked, answer, sound = true) {
  const at = Math.floor(Date.now() / 1000);
  const text = saidText(at, asked, answer);
  const [game] = findGames().map((wowDir) => ({ wowDir, spare: spareOf(wowDir) })).filter(({ spare }) => spare).sort((a, b) => b.spare.at - a.spare.at);
  if (!game) return { text, delivered: false, left: 0 };
  const used = readUsed();
  const list = Object.values(game.spare.list || {}).map(channelOf).filter(({ signal, slot }) => signal && slot
    && !used.some((one) => one.game === game.wowDir && one.signal === signal && one.slot === slot && one.at > game.spare.at - SAME_S));
  const [place] = list;
  if (!place) return { text, delivered: false, left: 0 };
  const { delivered } = deliver(game.wowDir, place, text, sound);
  if (delivered) fs.writeFileSync(usedFile(), JSON.stringify([...used, { game: game.wowDir, ...place, at: Math.max(at, game.spare.at) }].slice(-200)));
  return { text, delivered, left: list.length - (delivered ? 1 : 0) };
}
