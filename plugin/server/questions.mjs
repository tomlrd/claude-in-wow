// Questions sent from the game's Claude window: each
// travels in a photo, with the game state. Waiting for the next one, for the
// listening session (listen.mjs) and the silent mode (silent.mjs). The folder
// is watched, not polled: a photo's pages are read once the folder has been
// quiet a moment (a PNG takes a while to write, and pages come a second
// apart).

import fs from 'node:fs';
import { newestQuestion } from './photo.mjs';

const QUIET_MS = 1500;
const MAX_READ = 60e3; // characters
const MAX_PROPOSED = 5;
const LIMITS = { // what a module turned off in the addon takes from Claude
  web: 'do not search the web',
  addons: 'do not look in the installed addons, nor in their files',
  searches: 'two calls of tools at most for this answer',
  chips: 'no questions block',
  actions: 'no buttons block',
  route: 'no route block',
  why: 'no why block',
};
const NEWER = ['route', 'why']; // blocks the addon says it knows: an older one would show them as they are

// The modules the player turned off, by key (all on: none).
export function turnedOff(question) {
  return Array.isArray(question.options?.off) ? question.options.off.filter((key) => typeof key === 'string') : [];
}
const TOPICS = new Set('guild friends groups reputations currencies talents spells stats recipes achievements lockouts calendar played chat'.split(' '));

// For Claude, with a question: what was read in the game for it, and the player's
// limits (none at first).
export function readLines(question) {
  const read = question.read && JSON.stringify(question.read);
  const off = turnedOff(question), known = question.options?.blocks;
  const limits = off.filter((key) => LIMITS[key]).map((key) => LIMITS[key]);
  const missing = NEWER.filter((key) => !off.includes(key) && !(Array.isArray(known) && known.includes(key))).map((key) => LIMITS[key]);
  return [
    ...(read ? ['', 'Read in the game for this question, when it was asked:', read.length > MAX_READ ? `${read.slice(0, MAX_READ)}... (cut)` : read] : []),
    ...(limits.length ? ['', `The player's limits: ${limits.join('; ')}.`] : []),
    ...(missing.length ? ['', `Their addon is older: ${missing.join('; ')}.`] : []),
  ];
}

// Whether the player chose a session they see to answer it, not the silent mode.
export function bySession(question) {
  return question?.options?.by === 'session';
}

// The time a question was sent (unix seconds).
export function askedAt(photo) {
  return Number(photo.question.at) || photo.savedAt;
}

// The newest question sent after a time (unix seconds) in the Screenshots
// folder, as soon as there is one: a promise of the photo carrying it, or of
// null after ms milliseconds without one. takes(question): which ones.
export function waitForQuestion(screenshotsDir, after, ms, takes) {
  return new Promise((resolve) => {
    let watcher = null, timer = null, deadline = null;
    const finish = (photo) => {
      clearTimeout(timer);
      clearTimeout(deadline);
      if (watcher) watcher.close();
      resolve(photo);
    };
    const check = () => {
      let photo = null;
      try { photo = newestQuestion(screenshotsDir, after, takes); } catch { photo = null; }
      if (photo) finish(photo);
      return photo;
    };
    if (check()) return;
    fs.mkdirSync(screenshotsDir, { recursive: true });
    watcher = fs.watch(screenshotsDir, () => {
      clearTimeout(timer);
      timer = setTimeout(check, QUIET_MS);
    });
    deadline = setTimeout(() => finish(null), ms);
  });
}

// ------------------------------------------------ the questions kept

// Words that say nothing of a question's subject.
const EMPTY = new Set(('avec dans pour plus moins tres bien faire fait font faut quel quelle quels quelles quoi comment combien pourquoi quand est sont etre avoir leur leurs mes tes ses mon ton son notre votre '
  + 'gens tout tous toute toutes autre autres encore actuellement maintenant ensuite peux peut peuvent dois doit veux sais cette celui celle entre meme sans sous chez vers puis donc alors aussi comme '
  + 'what which where when with from that this they them there their have does about more most some other people now next should could would').split(' '));

function plain(text) {
  return String(text || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

// The stems of a text's words: five letters, without capitals nor accents.
function stems(text) {
  return new Set(plain(text).split(/[^a-z0-9]+/).filter((word) => word.length >= 4 && !EMPTY.has(word)).map((word) => word.slice(0, 5)));
}

// The addon's blocks (questions, buttons, marks, strings, routes...) put in a code block when a model
// forgot it: from their first line to the next empty one.
export function fenced(text) {
  text = text.replace(/\n+[ \t]*(?:#+[ \t]*|\*\*)?(?:questions?(?: suivantes?| (?:à|a) poser(?: ensuite)?| to ask(?: next)?)|next questions)[ \t]*:?(?:\*\*)?[ \t]*:?[ \t]*\n+((?:[ \t]*(?:[-*•][ \t]+)?[^\n]*\?[^\n]*(?:\n|$))+)\s*$/i,
    (whole, lines) => `\n\n[claude-in-wow] questions\n${lines.split('\n').map((line) => line.replace(/^[ \t]*[-*•][ \t]+/, '').trim()).filter(Boolean).join('\n')}`);
  const out = [];
  let inside = false, opened = false;
  for (const line of text.split('\n')) {
    if (/^\s*```/.test(line)) {
      if (opened) { out.push('```'); opened = false; }
      inside = !inside;
    } else if (!inside && /^\s*\[claude-in-wow\] *((questions|boutons|buttons|marques|marks|why)\s*$|(string|route) )/i.test(line)) {
      if (opened) out.push('```', '');
      out.push('```');
      opened = true;
    } else if (opened && !line.trim()) {
      out.push('```');
      opened = false;
    }
    out.push(line);
  }
  if (opened) out.push('```');
  return out.join('\n');
}

// An answer whose proposed questions are only those that share a word of the
// player's question or of the answer itself: a small model may propose anything.
// Those already asked (asked: earlier questions) go too, and those there twice;
// the block goes when none is left. { text, dropped }.
export function keepRelated(text, question, asked = []) {
  const block = /\n*```[^\n]*\n\s*\[claude-in-wow\] *[qQ]uestions[^\n]*\n([\s\S]*?)```/g;
  const subject = stems(`${question}\n${text.replace(/\n*```[\s\S]*?(```|$)/g, '')}`);
  const taken = new Set([question, ...asked].map(same));
  const dropped = [];
  const kept = text.replace(block, (whole, lines) => {
    const good = lines.split('\n').filter((line) => line.trim()).filter((line) => {
      const words = line.split('|')[0].trim();
      const fits = [...stems(words)].some((stem) => subject.has(stem)) && !taken.has(same(words));
      if (fits) taken.add(same(words)); else dropped.push(words);
      return fits;
    }).slice(0, MAX_PROPOSED).map(wellRead);
    return good.length ? `\n\n\`\`\`\n[claude-in-wow] questions\n${good.join('\n')}\n\`\`\`` : '';
  });
  return { text: kept.trim(), dropped };
}

// A proposed question as the addon takes it: what is to be read for it is
// "topics" and their names or "read" and a call; anything else goes.
function wellRead(line) {
  const [words, ...rest] = line.split('|');
  const wanted = rest.join('|').trim();
  const bare = wanted.replace(/^topics?\s+/i, '').split(/[\s,]+/).filter((name) => TOPICS.has(name.toLowerCase()));
  if (/^read\s+\S/i.test(wanted)) return `${words.trim()} | ${wanted}`;
  return bare.length ? `${words.trim()} | topics ${bare.join(' ').toLowerCase()}` : words.trim();
}

// A question's words, without capitals, accents nor punctuation, to tell it was asked.
function same(text) {
  return plain(text).split(/[^a-z0-9]+/).filter(Boolean).join(' ');
}
