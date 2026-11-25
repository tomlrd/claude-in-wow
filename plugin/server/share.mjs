// How much of the player's plan goes to the game's answers. Claude says how much
// of the plan is used, not by what: the game's part is estimated from the tokens
// of the Claude Code sessions of this computer, which it writes itself (one line a
// message, with its date, model and tokens; nothing else of them is read here).
// Each message weighs what it would cost (the plan's own count is not public).
// Claude used elsewhere (claude.ai, another computer) is not known: its part
// counts for the game and the rest alike.
// What the game's answers took is noted from what claude says (note) and kept by the
// caller too (kept): an answer beside the session is in no file, and the file of a
// session replaced is erased.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const WEEK_MS = 7 * 86400e3;
const CHUNK = 8 * 1024 * 1024;
const ASSISTANT = Buffer.from('"type":"assistant"');

// Of a model: the price of what it reads, against the others', what is read again
// from the cache costs of it; what it writes costs five times as much.
const PRICES = [
  [/fable-5-[2-9]|mythos-5-[2-9]/, 8, 0.025],
  [/(fable|mythos)-5-1/, 10, 0.025],
  [/fable|mythos/, 10, 0.1],
  [/opus-5-[5-9]/, 4, 0.05],
  [/opus/, 5, 0.1],
  [/sonnet-5-[5-9]/, 2, 0.05],
  [/sonnet-5/, 2, 0.1],
  [/sonnet/, 3, 0.1],
  [/haiku-4/, 1, 0.1],
  [/haiku/, 0.1, 0.1, 5], // five times as much past 100 000 tokens
];

export function weigh(model, usage) {
  const [, price, again, large = 1] = PRICES.find(([name]) => name.test(model)) || [];
  if (!price) return 0;
  const written = usage.cache_creation?.ephemeral_1h_input_tokens ?? 0, kept = Math.max(0, (usage.cache_creation_input_tokens || 0) - written);
  const read = (usage.input_tokens || 0) + (usage.cache_creation_input_tokens || 0) + (usage.cache_read_input_tokens || 0);
  return price * (read > 100e3 ? large : 1) / 1e6
    * ((usage.input_tokens || 0) + 1.25 * kept + 2 * written + again * (usage.cache_read_input_tokens || 0) + 5 * (usage.output_tokens || 0));
}

const same = (a, b) => {
  const [x, y] = [a, b].map((p) => path.resolve(String(p || '')));
  return process.platform === 'win32' ? x.toLowerCase() === y.toLowerCase() : x === y;
};

// Where Claude Code keeps its sessions, a folder for each folder worked in.
export function sessionsDir() {
  return path.join(process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude'), 'projects');
}

// Erases what Claude Code kept of a session (its file, and its folder when it has
// one): true once gone.
export function eraseSession(id, root = sessionsDir()) {
  if (!/^[\w-]{8,64}$/.test(String(id))) return false;
  let gone = false;
  for (const folder of fs.readdirSync(root, { withFileTypes: true })) {
    if (!folder.isDirectory()) continue;
    const file = path.join(root, folder.name, `${id}.jsonl`);
    if (!fs.existsSync(file)) continue;
    fs.rmSync(file);
    fs.rmSync(path.join(root, folder.name, id), { recursive: true, force: true });
    gone = true;
  }
  return gone;
}

// The sessions' tokens, for the game's sessions asked in a folder (dir).
export function planLedger(dir, { kept = [], root = sessionsDir() } = {}) {
  const messages = new Map(); // id -> { at (ms), model, weight, own }
  const offsets = new Map();  // file -> how far it was read
  let reading = null;

  // A message is in several lines (one a block), in several files when a session is
  // continued in another: the last count is the largest.
  function add(id, at, model, usage, own) {
    const weight = weigh(model, usage), known = messages.get(id);
    if (!known) messages.set(id, { at, model, weight, own });
    else if (weight > known.weight) known.weight = weight;
  }

  function line(buffer, since) {
    if (!buffer.includes(ASSISTANT)) return;
    let entry = null;
    try { entry = JSON.parse(buffer.toString('utf8')); } catch { return; }
    const { message, timestamp, entrypoint, cwd } = entry;
    const at = Date.parse(timestamp);
    if (entry.type !== 'assistant' || !message?.id || !message.usage || !(at >= since)) return;
    add(message.id, at, String(message.model), message.usage, entrypoint === 'sdk-cli' && same(cwd, dir));
  }

  async function read(file, size, since) {
    let from = offsets.get(file) || 0;
    if (from > size) from = 0; // written again
    if (from === size) return;
    const handle = await fs.promises.open(file);
    try {
      let rest = Buffer.alloc(0);
      for (let at = from; at < size;) {
        const { bytesRead, buffer } = await handle.read(Buffer.alloc(Math.min(CHUNK, size - at)), 0, Math.min(CHUNK, size - at), at);
        if (!bytesRead) break;
        at += bytesRead;
        const data = Buffer.concat([rest, buffer.subarray(0, bytesRead)]);
        let start = 0;
        for (let end = data.indexOf(10); end >= 0; end = data.indexOf(10, start)) {
          line(data.subarray(start, end), since);
          start = end + 1;
        }
        rest = data.subarray(start);
        from = at - rest.length; // a line still being written is read next time
      }
    } finally { await handle.close(); }
    offsets.set(file, from);
  }

  async function readAll() {
    const since = Date.now() - WEEK_MS - 3600e3;
    for (const [id, { at }] of messages) if (at < since) messages.delete(id);
    let names = [];
    try { names = await fs.promises.readdir(root, { recursive: true }); } catch { return; }
    for (const name of names) {
      if (!name.endsWith('.jsonl')) continue;
      const file = path.join(root, name);
      try {
        const { size, mtimeMs } = await fs.promises.stat(file);
        if (mtimeMs >= since) await read(file, size, since);
      } catch { /* gone, or not to be read: the others */ }
    }
  }

  for (const { id, at, model, usage } of kept) add(id, at, model, usage, true);

  return {
    // Reads what was written since the last time; the first one reads a week.
    refresh() {
      reading ||= readAll().finally(() => { reading = null; });
      return reading;
    },
    note(id, at, model, usage) { add(id, at, model, usage, true); },
    // The game's part, 0 to 1, since a time (unix seconds), of a model's family
    // when the plan counts it apart; null without any message.
    share(from, family) {
      let own = 0, all = 0;
      for (const message of messages.values()) {
        if (message.at < from * 1000 || family && !message.model.includes(family)) continue;
        all += message.weight;
        if (message.own) own += message.weight;
      }
      return all > 0 ? own / all : null;
    },
  };
}
