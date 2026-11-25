// Waits for the next question the player sends from the game's Claude window
// (questions.mjs), prints it and exits. Run in the background by the assistant
// (the listen tool gives the command), its exit wakes the assistant, which
// answers and listens again.
// node listen.mjs [--after <unix seconds>] [--hours <hours>]

import { acknowledge } from './deliver.mjs';
import { screenshotsDir, servedGames } from './game.mjs';
import { MODULES_DIR } from './modules.mjs';
import { askedAt, bySession, readLines, waitForQuestion } from './questions.mjs';
import { running } from './silent-mode.mjs';

function option(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? Number(process.argv[index + 1]) : NaN;
  return Number.isFinite(value) ? value : fallback;
}

const after = option('after', Math.floor(Date.now() / 1000));
const hours = option('hours', 4);

const games = servedGames();
if (!games.length) {
  console.log('World of Warcraft was not found: set CIW_WOW_DIR to the game\'s folder (such as _retail_).');
  process.exit(1);
}

const stamp = (seconds) => new Date(seconds * 1000).toLocaleString();

// the questions the silent mode leaves: all of them when it does not run (an update is its own)
const ours = (question) => question.kind !== 'update' && (bySession(question) || !running());

// in whichever version it comes first
const photo = await Promise.any(games.map((game) => waitForQuestion(screenshotsDir(game), after, hours * 3600e3, ours).then((p) => (p ? { ...p, wowDir: game } : Promise.reject(new Error('none')))))).catch(() => null);
if (!photo) {
  console.log(`Stopped listening: no question from the game in ${hours} hours, since ${stamp(after)}. Call the listen tool to listen again.`);
} else {
  const question = photo.question;
  acknowledge(photo.wowDir, question);
  const at = askedAt(photo);
  console.log([
    `Question from the game: ${photo.key}, ${stamp(at)}, kind "${question.kind || 'free'}".`,
    '',
    question.text,
    '',
    'The game state this question was asked in is in the photo: game_state, quests, inventory and the other tools read it.',
    ...readLines(question),
    `How to answer it: the files of ${MODULES_DIR} (read them once).`,
    `Answer here, call answer_to_game with question=${at}, then run the command it gives in the background to wait for the next question (after=${at}).`,
  ].join('\n'));
}
process.exit(0);
