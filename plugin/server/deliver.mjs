// Answers put into the running game (the addon's Inbox.lua), for the questions
// that ask for it (question.signal and .slot, the player's setting): the answer
// is written, as a Lua text, in the one file of an addon loaded on demand
// (claude-in-wow_SNNN), then a chime in an empty sound file of the addon
// (claude-in-wow\Inbox\NNN.wav), which the game then hears.
// A question received is acknowledged the same way, with a sound the player does not
// hear, in another of these files (claude-in-wow\Inbox\aNNN.wav): the game knows that
// someone answers.
// Only these files, made beforehand (tools/inbox.mjs, slots.mjs), are ever
// written, and emptied again once the answer has arrived or is too old.

import fs from 'node:fs';
import path from 'node:path';
import { EMPTY_SLOT, MAX_SLOTS, slotFile } from './slots.mjs';

export const SIGNALS = 250; // as tools/inbox.mjs makes them
const STALE_MS = 10 * 60e3;

const number = (value, max) => (Number.isInteger(value) && value >= 1 && value <= max ? value : null);

export function signalFile(wowDir, signal) {
  return path.join(wowDir, 'Interface', 'AddOns', 'claude-in-wow', 'Inbox', `${String(signal).padStart(3, '0')}.wav`);
}

export function ackFile(wowDir, signal) {
  return path.join(wowDir, 'Interface', 'AddOns', 'claude-in-wow', 'Inbox', `a${String(signal).padStart(3, '0')}.wav`);
}

// { signal, slot } of a question, each null when it has none or it is not one
// of the addon's.
export function channelOf(question) {
  return { signal: number(question?.signal, SIGNALS), slot: number(question?.slot, MAX_SLOTS) };
}

// A file made at the installation: never created here, nor written through a link.
function isOurs(file) {
  try { return fs.lstatSync(file).isFile(); } catch { return false; }
}

// Writes a file, again a moment later if the game is reading it.
function write(file, content) {
  for (let tries = 1; ; tries += 1) {
    try { return fs.writeFileSync(file, content); } catch (error) {
      if (tries === 4) throw error;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 150);
    }
  }
}

// A Lua long text, its brackets longer than any in the text.
function luaText(text) {
  let level = 1;
  while (text.includes(`]${'='.repeat(level)}]`)) level += 1;
  const equals = '='.repeat(level);
  return `ClaudeInWoWInbox = [${equals}[\n${text}\n]${equals}]\n`;
}

// Puts an answer (marked with its question) in the game. { delivered } says
// the game was told; without a slot it only learns that the answer is ready.
// sound: the chime, else a sound as long but silent.
export function deliver(wowDir, question, text, sound = true) {
  const { signal, slot } = channelOf(question);
  if (!wowDir || !signal) return { delivered: false };
  const flag = signalFile(wowDir, signal);
  if (!isOurs(flag)) return { delivered: false };
  try {
    if (slot && isOurs(slotFile(wowDir, slot))) write(slotFile(wowDir, slot), EMPTY_SLOT + luaText(text));
    write(flag, sound ? chime() : silence());
    return { delivered: true };
  } catch (error) {
    return { delivered: false, error: error.message };
  }
}

// Tells the game that a question was received.
export function acknowledge(wowDir, question) {
  const { signal } = channelOf(question);
  if (!wowDir || !signal) return;
  try { if (isOurs(ackFile(wowDir, signal))) write(ackFile(wowDir, signal), silence()); } catch { /* not told */ }
}

// Empties a question's files again.
export function withdraw(wowDir, question) {
  const { signal, slot } = channelOf(question);
  if (!wowDir) return;
  const files = [[slot && slotFile(wowDir, slot), EMPTY_SLOT], [signal && signalFile(wowDir, signal), ''], [signal && ackFile(wowDir, signal), '']];
  for (const [file, empty] of files) {
    try { if (file && isOurs(file)) write(file, empty); } catch { /* in use: emptied another time */ }
  }
}

// Empties what earlier answers left, but for the questions kept.
export function tidy(wowDir, kept) {
  if (!wowDir) return;
  const left = (file, emptySize) => {
    try {
      const stat = fs.lstatSync(file);
      return stat.isFile() && stat.size > emptySize && Date.now() - stat.mtimeMs > STALE_MS;
    } catch { return false; }
  };
  const used = kept.map(channelOf);
  for (let signal = 1; signal <= SIGNALS; signal += 1) {
    if (!used.some((q) => q.signal === signal) && (left(signalFile(wowDir, signal), 0) || left(ackFile(wowDir, signal), 0))) withdraw(wowDir, { signal });
  }
  for (let slot = 1; slot <= MAX_SLOTS; slot += 1) {
    if (!used.some((q) => q.slot === slot) && left(slotFile(wowDir, slot), EMPTY_SLOT.length)) withdraw(wowDir, { slot });
  }
}

// ------------------------------------------------------------- the sounds

const RATE = 22050;

// A .wav (16 bits, one channel) of samples from -1 to 1.
function wav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((sample, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32767), i * 2));
  const head = Buffer.alloc(44);
  head.write('RIFF', 0);
  head.writeUInt32LE(36 + data.length, 4);
  head.write('WAVEfmt ', 8);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20);
  head.writeUInt16LE(1, 22);
  head.writeUInt32LE(RATE, 24);
  head.writeUInt32LE(RATE * 2, 28);
  head.writeUInt16LE(2, 32);
  head.writeUInt16LE(16, 34);
  head.write('data', 36);
  head.writeUInt32LE(data.length, 40);
  return Buffer.concat([head, data]);
}

// Two soft notes, the second higher (E5, then A5).
export function chime() {
  const notes = [{ at: 0, hz: 659.26 }, { at: 0.13, hz: 880 }];
  const samples = Array.from({ length: Math.round(RATE * 0.8) }, (_, i) => {
    const t = i / RATE;
    let sample = 0;
    for (const note of notes) {
      const since = t - note.at;
      if (since < 0) continue;
      const envelope = Math.min(1, since / 0.008) * Math.exp(-since * 6);
      sample += envelope * (Math.sin(2 * Math.PI * note.hz * since) + 0.25 * Math.sin(4 * Math.PI * note.hz * since));
    }
    return sample * 0.22 * Math.min(1, (0.8 - t) / 0.05);
  });
  return wav(samples);
}

// As long, but not heard by the player.
export function silence() {
  return wav(new Array(Math.round(RATE * 0.8)).fill(0));
}
