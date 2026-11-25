// The silent mode: Claude answers the questions sent from the game's Claude
// window without a conversation open. This program watches for questions
// (photos in the Screenshots folder), and answers them, several at once when
// they overlap: it asks Claude Code without a window (claude -p: the player's
// own Claude, signed in with their account, with its plugins and so these
// tools), the web and the game's files, to read only (no one is there to allow a
// command or a file written), unless the player limits them; with what the
// modules say (modules.mjs) in place of Claude Code's own instructions, which
// would be read again at every step;
// puts the answer in the game for the questions that ask for it
// (deliver.mjs), and in the clipboard in any case, with a sound when the game
// does not make one itself (clipboard.mjs).
//
// All the conversations (tabs) of the game's window share one Claude session,
// resumed at each question and kept when the silent mode is stopped and
// started again. What a session holds is read again at every question: at a
// twentieth of the price while Claude keeps it cached (an hour after its last
// use, as claude's usage says), at twice the price once it no longer does. So
// a session is renewed after an hour's pause, or when the effort changes (the
// cache is lost too), if it holds more than a new one would; when it is very
// large anyway; when the model changes; or when the player asks
// (question.newSession, which forgets everything). A renewed session starts with a recap: the last
// questions and the start of their answers, noted here (no call to Claude for
// it). Only one is kept: what Claude Code saved of the one before is erased.
// A question asked while another is being answered is answered at the same
// time, beside the session: a run of its own with that same recap, nothing
// saved (--no-session-persistence), so that no other session appears. The
// session is told of it at its next question.
//
// The player's choices come with each question (question.model, question.effort
// and question.options, from the window): the model and its effort, whether a
// session is renewed by itself, past how many tokens, after how long a pause, and remembering how many questions,
// answers at once or in turn, the sounds, how
// many slots the answers come through (slots.mjs).
// The clipboard holds one text: every answer not pasted yet goes in it
// together, each with its mark (the window sorts them out), until a question
// tells which answers have arrived (question.got), or they are too old.
// Started and stopped by the silent_mode tool (silent-mode.mjs), which keeps
// its state; it logs what it does next to it.
// node silent.mjs --dir <folder Claude works in>
// CIW_CLAUDE (tests): a script run with node in place of claude.
// CIW_CACHE_S (tests): how long a session stays cached; CIW_CATCH_UP_S: how old a
// question it answers once started.

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { answerMark, playReceived, toClipboard } from './clipboard.mjs';
import { acknowledge, channelOf, deliver, tidy, withdraw } from './deliver.mjs';
import { flavorOf } from './flavors.mjs';
import { fold, loadData, screenshotsDir, servedGames } from './game.mjs';
import { failureText } from './messages.mjs';
import { ADDONS_ENV, systemPrompt, webSites } from './modules.mjs';
import { claudeLanguage } from './language.mjs';
import { linkNames, people, placesToSearch } from './names.mjs';
import { questionsAfter } from './photo.mjs';
import { claudeCommand } from './claude.mjs';
import { bySession, fenced, keepRelated, readLines, turnedOff } from './questions.mjs';
import { eraseSession, planLedger } from './share.mjs';
import { readState, running, silentFiles, writeState } from './silent-mode.mjs';
import { setSlots, USUAL_SLOTS } from './slots.mjs';
import { putStrings } from './strings.mjs';
import { answerUpdate, applyWaiting, daily, newerPlugin, waitingUpdates } from './updates.mjs';

const TOOLS = 'mcp__claude-in-wow';
const FILE_TOOLS = ['Read', 'Grep', 'Glob'];
const MAX_PEOPLE = 400;
const SETUP = 'lean-3'; // how Claude is started: a session of another way is left
const MODELS = ['fable', 'opus', 'sonnet', 'haiku']; // the names claude takes for the latest of each
const EFFORTS = ['low', 'medium', 'high', 'xhigh', 'max'];
const CACHE_S = Number(process.env.CIW_CACHE_S || 3600); // Claude keeps a session cached for an hour
const COLD = 60e3;   // tokens past which a session no longer cached costs more than a new one, unless the player
                     // says another (renewPauseAt), as how long a pause is (renewPause, in seconds, 0: no pause counts)
const HEAVY = 250e3; // and past which it is renewed in any case, unless the player says another (renewAt)
const ANSWER_TIMEOUT_MS = 6 * 60e3;
const QUIET_MS = 1500; // a photo is read once the folder has been quiet this long
const OUTBOX_S = 2 * 3600;
const CATCH_UP_S = Number(process.env.CIW_CATCH_UP_S || 600); // questions asked so long before it started are answered
const SHARE_MS = 3000; // an answer does not wait longer for the game's part of the plan
const WEEK_S = 7 * 86400;
const MAX_EXCHANGES = 500; // kept, and as many as "all" may be
const RECAP_EXCHANGES = 6; // unless the player says another (remember)
const RECAP_CHARS = 400;

const dirIndex = process.argv.indexOf('--dir');
const dir = dirIndex >= 0 ? process.argv[dirIndex + 1] : process.cwd();

function log(line) {
  try { fs.appendFileSync(silentFiles().log, `${new Date().toLocaleString()}  ${line}\n`); } catch { /* no log */ }
}

const now = () => Math.floor(Date.now() / 1000);

// one at a time; and what went wrong in one answer does not end the others
const other = running();
if (other && other.pid !== process.pid) process.exit(0);
setTimeout(() => { if (readState()?.pid !== process.pid) process.exit(0); }, 1500); // started twice at once: the last one stays
for (const event of ['uncaughtException', 'unhandledRejection']) process.on(event, (error) => log(`went wrong: ${error?.stack || error}`));

// the Claude session and what was said, kept across restarts, with the answers
// not pasted yet
const before = readState() || {};
const state = {
  pid: process.pid, started: now(), dir, answered: 0,
  wanted: true, // until the player stops it
  after: Math.max(before.after || 0, now() - CATCH_UP_S), // the last question seen
  session: before.session || null, asked: before.asked || 0,
  setup: before.setup || null,
  chat: before.chat || false,     // players' chat was read in it
  game: before.game || null,      // the game it was asked from
  context: before.context || 0,   // tokens the session holds
  base: before.base || 0,         // of them, what every session starts with
  usedAt: before.usedAt || 0,     // and when it last answered
  model: before.model || null,    // the model asked of it (null: the player's default)
  effort: before.effort || null,  // and its effort
  usedModel: before.usedModel || null, // the one that answered last
  exchanges: Array.isArray(before.exchanges) ? before.exchanges : [], // { tab, question, answer, told }: told, the session knows it
  people: Array.isArray(before.people) ? before.people : [], // names of players and guilds read: never looked up on the web
  left: Array.isArray(before.left) ? before.left : [], // the sessions replaced, to erase
  spent: (Array.isArray(before.spent) ? before.spent : Array.isArray(before.asides) ? before.asides : []).filter(({ at }) => at / 1000 > now() - WEEK_S), // what the answers took, this week (share.mjs)
  outbox: Array.isArray(before.outbox) ? before.outbox : [], // { at, time, text, signal, slot }, the answer's mark first in text
  waiting: 0,
};
writeState(state);
const ledger = planLedger(dir, { kept: state.spent });
ledger.refresh();

// every version of the game with the addon; its questions are answered in it
const games = servedGames();
if (!games.length) {
  log('World of Warcraft was not found: stopped.');
  process.exit(1);
}
const gameOf = (answered) => (games.includes(answered.wowDir) ? answered.wowDir : games[0]);
for (const game of games) tidy(game, state.outbox.filter((answered) => gameOf(answered) === game));

// As many slots as the player picks (slots.mjs): with each question, and at the
// start as the game last saved it, for the game's next start to find them.
function followSlots(wowDir, count) {
  try {
    const { made, removed } = setSlots(wowDir, count);
    if (made || removed) log(`slots: ${made} made, ${removed} taken away, for the game's next start`);
  } catch (error) { log(`slots: ${error.message}`); }
}
for (const game of games) {
  try {
    const { arrive, slots } = loadData(game).db?.options || {};
    followSlots(game, arrive === false ? 0 : slots ?? USUAL_SLOTS);
  } catch (error) { log(`slots: ${error.message}`); }
}

// ------------------------------------------------------------- the questions

const queue = []; // { question, at, wowDir }, the first to answer first

// The updates (updates.mjs): asked by the game, or once a day. A newer plugin takes over
// once nothing is being answered; an addon downloaded is put in place once the game is
// closed, which is looked for only while one waits.
const APPLY_MS = 15e3, DAILY_MS = 6 * 3600e3;
let applying = null;
function watchGame() {
  if (applying || !waitingUpdates().length) return;
  applying = setInterval(() => {
    try {
      for (const { version, error } of applyWaiting()) log(error ? `addon not updated to ${version}: ${error}` : `addon updated to ${version}`);
    } catch (error) { log(`updates: ${error.message}`); }
    if (waitingUpdates().length) return;
    clearInterval(applying);
    applying = null;
  }, APPLY_MS);
}

function handOver() {
  const found = active === 0 && queue.length === 0 && newerPlugin();
  if (!found) return;
  log(`plugin ${path.basename(found)}: it goes on`);
  const start = `setTimeout(() => import(${JSON.stringify(pathToFileURL(path.join(found, 'server', 'silent-mode.mjs')).href)}).then((m) => m.start(${JSON.stringify(dir)})), 2500)`;
  spawn(process.execPath, ['--input-type=module', '-e', start], { detached: true, stdio: 'ignore', windowsHide: true }).unref();
  process.exit(0);
}

async function updating(question, wowDir) {
  log('updates: asked from the game');
  let text = '';
  try { text = await answerUpdate(question, wowDir); } catch (error) { log(`updates: ${error.message}`); }
  if (text) deliver(wowDir, question, text, false);
  watchGame();
  setTimeout(handOver, 20e3); // once the game has it
}

async function lookForUpdates() {
  try { await daily(log); } catch (error) { log(`updates: ${error.message}`); }
  watchGame();
  handOver();
}
setTimeout(lookForUpdates, 20e3);
setInterval(lookForUpdates, DAILY_MS);
let wake = null;

// Watches a game's screenshots for the questions that come in them, in order.
function watch(wowDir) {
  const screenshots = screenshotsDir(wowDir);
  let after = state.after, quiet = null;
  const see = () => {
    let found = [];
    try { found = questionsAfter(screenshots, after); } catch { found = []; }
    for (const { question, at } of found) {
      after = Math.max(after, at);
      if (question.kind === 'update') {
        acknowledge(wowDir, question);
        updating(question, wowDir);
        continue;
      }
      if (bySession(question)) continue; // a session the player sees answers it
      acknowledge(wowDir, question);
      queue.push({ question, at, wowDir });
    }
    if (found.length) {
      state.after = Math.max(state.after, after);
      writeState(state);
      if (wake) wake();
    }
  };
  fs.mkdirSync(screenshots, { recursive: true });
  fs.watch(screenshots, () => {
    clearTimeout(quiet);
    quiet = setTimeout(see, QUIET_MS);
  });
  see();
}
games.forEach(watch);

// ------------------------------------------------------------- asking Claude

// The questions and the start of their answers, for a run that does not know them.
function recapLines(exchanges, title) {
  if (!exchanges.length) return [];
  return ['', title, ...exchanges.map((e) => `- ${e.tab ? `[tab "${e.tab}"] ` : ''}Asked: ${e.question}\n  Answered: ${e.answer}`)];
}

// What Claude is started with: these tools alone, and what the modules say.
const files = path.dirname(silentFiles().state);
const nameOf = (wowDir) => path.basename(wowDir).replace(/\W/g, '');
const mcpFile = (wowDir, addons) => path.join(files, `claude-in-wow-mcp${nameOf(wowDir)}${addons ? '-addons' : ''}.json`);
const systemFile = (wowDir) => path.join(files, `claude-in-wow-system${nameOf(wowDir)}.md`);
for (const game of games) {
  for (const addons of [false, true]) { // the same tools; those on the player's addons answer only in the second
    fs.writeFileSync(mcpFile(game, addons), JSON.stringify({ mcpServers: { 'claude-in-wow': {
      command: process.execPath, args: [path.join(path.dirname(fileURLToPath(import.meta.url)), 'server.mjs')],
      env: { [ADDONS_ENV]: addons ? 'asked' : 'no', CIW_SILENT_DIR: files, CIW_WOW_DIR: game },
    } } }));
  }
}

function writeSystem(wowDir) {
  let db = null;
  try { db = loadData(wowDir).db; } catch { db = null; }
  fs.writeFileSync(systemFile(wowDir), systemPrompt(dir, db, wowDir));
}

function prompt(question, recap, web) {
  return [
    `[claude-in-wow, silent mode] The player asked from the game's Claude window (kind "${question.kind || 'free'}"):`,
    '',
    question.text,
    '',
    ...(/^[a-z]{2}[A-Z]{2}$/.test(question.options?.language) ? [`The window is in ${question.options.language}: answer in the language of the question, in this one when it does not tell.`] : []),
    ...(question.tab && question.tab !== question.text ? [`Asked in the window's tab "${question.tab}" (this session answers all the tabs).`] : []),
    ...readLines(question),
    ...recap,
    ...(web ? ['', 'What neither the game nor you are sure of: search the web for it before you answer. Never answer that you have not looked.'] : []),
  ].join('\n');
}

// The environment for claude: this program is started from a Claude session
// (the silent_mode tool), whose variables point claude at that session's own
// connection, which ends with it. Without them, claude uses its own sign-in
// (claude auth login). CLAUDE_CONFIG_DIR, the player's own choice, stays.
function claudeEnv() {
  return Object.fromEntries(Object.entries(process.env)
    .filter(([key]) => key === 'CLAUDE_CONFIG_DIR' || !/^(CLAUDE|ANTHROPIC)/i.test(key)));
}

const tokens = (usage) => (usage?.input_tokens || 0) + (usage?.cache_creation_input_tokens || 0)
  + (usage?.cache_read_input_tokens || 0) + (usage?.output_tokens || 0);

// What claude's lines (stream-json) say: the result, the model that answered,
// the size of what it read for its last message, and the tokens the whole
// answer took (all of its calls: read, written and, in cached, read again from
// the cache), as the result's usage says (its modelUsage counts the session's
// earlier questions too). And, with a plan (Pro, Max), how much of it is used:
// claude says it by itself, with each answer (rate_limit_event).
function readReply(out) {
  let result = null, model = null, context = 0, first = 0, plan = null;
  const calls = new Map(); // a message is in several lines (one a block)
  for (const line of out.split(/\r?\n/)) {
    if (!line) continue;
    let entry = null;
    try { entry = JSON.parse(line); } catch { continue; }
    if (entry.type === 'result') result = entry;
    if (entry.type === 'rate_limit_event') plan = planOf(entry.rate_limit_info) || plan;
    const usage = entry.message?.usage;
    if (entry.type !== 'assistant' || !usage || entry.parent_tool_use_id) continue;
    if (!String(entry.message.model || '<').startsWith('<')) model = entry.message.model;
    context = tokens(usage);
    calls.set(entry.message.id, { id: entry.message.id, at: Date.now(), model: entry.message.model, usage });
    if (!first) first = context - (usage.output_tokens || 0);
  }
  return { result, model, plan, context, first, calls: calls.size, messages: [...calls.values()].filter(({ id }) => id), spent: { total: tokens(result?.usage), cached: result?.usage?.cache_read_input_tokens || 0 } };
}

// The plan's windows: [{ window: '5h' | '7d' | '7d-opus'..., percent, resets
// (unix seconds) }]; null when claude does not say.
function planOf(info) {
  const windows = Object.entries(info?.unifiedWindows || {}).flatMap(([name, { utilization, resetsAt } = {}]) => {
    const [, hours, only] = /^(five_hour|seven_day)(?:_([a-z]+))?$/.exec(name) || [];
    if (!hours || !Number.isFinite(utilization)) return [];
    return [{ window: `${hours === 'five_hour' ? '5h' : '7d'}${only ? `-${only}` : ''}`, percent: Math.round(utilization * 100), resets: Math.floor(Number(resetsAt) || 0) }];
  });
  return windows.length ? windows : null;
}

// Claude's reply: { text, session, model, context, spent } or { error }; plan in
// both (the plan may be why there is no answer).
// session: to resume; aside: nothing saved.
function askClaude(text, { session, aside, model, effort, web, addons, wowDir }) {
  return new Promise((resolve) => {
    // any page, but a list of sites once players' chat is in the session: one of
    // them might write there a page to open, with what Claude knows in its address
    const pages = web === 'sites' ? webSites(dir).map((site) => `WebFetch(domain:${site})`) : ['WebFetch'];
    const allowed = [TOOLS, ...(web ? ['WebSearch', ...pages] : []), ...(addons ? FILE_TOOLS : [])];
    const tools = [...(web ? ['WebSearch', 'WebFetch'] : []), ...(addons ? FILE_TOOLS : [])];
    const args = ['-p', '--output-format', 'stream-json', '--verbose', '--allowedTools', allowed.join(','), '--strict-mcp-config', '--mcp-config', mcpFile(wowDir, addons),
      '--tools', tools.join(','), ...(addons ? ['--add-dir', wowDir] : []), '--disable-slash-commands', '--no-chrome', '--system-prompt-file', systemFile(wowDir)];
    writeSystem(wowDir);
    if (session) args.push('--resume', session);
    if (aside) args.push('--no-session-persistence');
    if (model) args.push('--model', model);
    if (effort) args.push('--effort', effort);
    const fake = process.env.CIW_CLAUDE;
    const [program, ...first] = fake ? [process.execPath, fake] : claudeCommand();
    const child = spawn(program, [...first, ...args], { cwd: dir, env: claudeEnv(), windowsHide: true });
    let out = '', err = '', failed = null;
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', (data) => { out += data; });
    child.stderr.on('data', (data) => { err += data; });
    child.on('error', (error) => { failed = error; });
    const timer = setTimeout(() => { failed = new Error('no answer in time'); child.kill(); }, ANSWER_TIMEOUT_MS);
    child.on('close', (status) => {
      clearTimeout(timer);
      if (failed) return resolve({ error: failed.message });
      const { result, model: used, plan, context, first, calls, messages, spent } = readReply(out);
      if (!result || result.is_error || typeof result.result !== 'string') {
        return resolve({ error: (result && result.result) || err.trim().split('\n').pop() || `exit ${status}`, plan });
      }
      return resolve({ text: result.result.trim(), session: result.session_id, model: used, plan, context, first, calls, messages, spent: { ...spent, output: result.usage?.output_tokens || 0 } });
    });
    child.stdin.on('error', () => { /* the process could not start: told by "error" */ });
    child.stdin.end(text);
  });
}

// The plan's windows, with the game's part of each (own: in hundredths of a
// percent of the plan), when it is known in time.
async function withShare(plan) {
  let late = null;
  const known = await Promise.race([ledger.refresh().then(() => true), new Promise((resolve) => { late = setTimeout(resolve, SHARE_MS, false); })]);
  clearTimeout(late);
  if (!known) return plan;
  return plan.map((used) => {
    const [, span, family] = /^(5h|7d)(?:-(.+))?$/.exec(used.window);
    const share = used.resets ? ledger.share(used.resets - (span === '5h' ? 5 * 3600 : WEEK_S), family) : null;
    return share === null ? used : { ...used, own: Math.min(used.percent * 100, Math.ceil(share * used.percent * 100)) };
  });
}

// ------------------------------------------------------------- the answers

// Keeps the answers still wanted; the files of the others in the game are emptied.
function keepAnswers(wanted) {
  const gone = state.outbox.filter((answered) => !wanted(answered));
  state.outbox = state.outbox.filter(wanted);
  const free = (key, value, game) => (state.outbox.some((answered) => gameOf(answered) === game && answered[key] === value) ? null : value); // else another's by now
  for (const { signal, slot, wowDir } of gone.map((answered) => ({ ...answered, wowDir: gameOf(answered) }))) withdraw(wowDir, { signal: free('signal', signal, wowDir), slot: free('slot', slot, wowDir) });
}

// The answers not pasted yet, each with its mark, as one text in the clipboard.
function copyOutbox(sound) {
  keepAnswers((answered) => now() - answered.time < OUTBOX_S);
  return toClipboard(state.outbox.map((answer) => answer.text).join('\n\n'), sound);
}

// Where an answer's tokens went: the base every session starts with, what it
// remembers, the question with what was read for it, the searches (each step
// after the first reads everything again), the answer; and how many steps.
function detailOf(reply, asked, read, fresh) {
  const data = read ? JSON.stringify(read).length : 0; // about two characters a token, against three and a half in a text
  const question = Math.round(data / 2 + Math.max(0, asked.length - data) / 3.5);
  if (fresh) state.base = Math.max(0, reply.first - question);
  const base = Math.min(state.base || reply.first, reply.first);
  const memory = Math.max(0, reply.first - base - question);
  return [base, memory, Math.max(0, reply.first - base - memory), Math.max(0, reply.spent.total - reply.first - reply.spent.output), reply.spent.output, reply.calls];
}

let active = 0;       // questions being answered
let mainBusy = false; // one of them in the session itself, the others beside it
let generation = 0;   // a session the player asked to leave is not taken up again

function leaveSession(why) {
  if (state.session) {
    log(why);
    state.left.push(state.session);
  }
  state.session = null;
  state.asked = 0;
  state.context = 0;
  state.chat = false;
}

// Erases the sessions replaced, now that another answers.
function eraseLeft() {
  state.left = state.left.filter((id) => {
    if (!id || id === state.session) return false;
    try { eraseSession(id); } catch (error) {
      log(`a session not erased: ${error.message}`);
      return error.code !== 'ENOENT';
    }
    return false;
  });
}

// The language of the player's window: the one it says, else the game's.
function shownIn(question, wowDir) {
  if (/^[a-z]{2}[A-Z]{2}$/.test(question.options?.language)) return question.options.language;
  try { return loadData(wowDir).db?.game?.locale; } catch { return null; }
}

// A number the player picked, the usual one when it is none.
const within = (value, least, most, usual) => (Number.isFinite(value) && value >= least && value <= most ? Math.floor(value) : usual);
const lastExchanges = (count) => (count > 0 ? state.exchanges.slice(-count) : []);

// An answer as the game shows it: the names in bold made links, unless the
// player limits the web (never those of players nor of places), and the strings
// in the place of their marks.
async function finished(answer, question, off, wowDir) {
  if (off.includes('web')) return putStrings(answer);
  const leave = people(question.read, new Set(state.people));
  state.people = [...leave].slice(-MAX_PEOPLE);
  try {
    const { db } = loadData(wowDir);
    for (const { name } of Array.isArray(db?.places) ? db.places : []) leave.add(fold(name));
    for (const key of Object.keys(db?.characters || {})) leave.add(fold(key));
  } catch { /* no data: the names alone */ }
  let text = answer;
  try { text = await linkNames(answer, leave, undefined, placesToSearch(wowDir)); } catch (error) { log(`names: ${error.message}`); }
  return putStrings(text);
}

// Answers one question; aside: beside the session, which another is using.
async function answer(question, at, wowDir) {
  const aside = mainBusy;
  if (!aside) mainBusy = true;
  try { await answerIn(question, at, aside, wowDir); } finally { if (!aside) mainBusy = false; }
}

async function answerIn(question, at, aside, wowDir) {
  const begun = Date.now();
  const options = question.options || {};
  const model = MODELS.includes(question.model) ? question.model : null;
  const effort = EFFORTS.includes(question.effort) ? question.effort : null;
  log(`question (${[games.length > 1 && flavorOf(wowDir).key, question.kind || 'free', aside && 'aside', model, effort && `effort ${effort}`].filter(Boolean).join(', ')}): ${question.text}`);
  if (options.soundStart === true) playReceived();
  followSlots(wowDir, options.slots);
  // the window says which answers it has
  const got = new Set(Array.isArray(question.got) ? question.got.map(Number) : []);
  keepAnswers((answered) => gameOf(answered) !== wowDir || !got.has(answered.at));
  if (question.newSession) {
    generation += 1;
    state.exchanges = [];
    leaveSession('a new Claude session, asked by the player');
  }
  if (!aside) {
    const pause = within(options.renewPause, 0, 30 * 86400, null);
    const paused = pause === null ? now() - state.usedAt >= CACHE_S : pause > 0 && now() - state.usedAt >= pause;
    const cold = state.context > within(options.renewPauseAt, 0, 1e6, COLD) && (paused || effort !== state.effort);
    if (options.renew !== false && state.context > (options.renewAt === 0 ? Infinity : within(options.renewAt, 20e3, 1e6, HEAVY))) leaveSession(`the session holds ${state.context} tokens: renewed, with a recap`);
    else if (options.renew !== false && cold) leaveSession(`the session (${state.context} tokens), ${paused ? 'after a pause' : 'no longer cached'}: renewed, with a recap`);
    else if (state.session && state.setup !== SETUP) leaveSession('another way of starting Claude: the session is renewed, with a recap');
    else if (state.session && model !== state.model) leaveSession('another model: the session is renewed, with a recap');
    else if (state.session && state.game && state.game !== wowDir) leaveSession('another version of the game: the session is renewed, with a recap');
  }

  const era = generation;
  const off = turnedOff(question);
  const chat = Boolean(question.read?.chat) || !aside && state.chat;
  const web = off.includes('web') ? null : chat ? 'sites' : 'any';
  const run = (session) => {
    const news = session ? state.exchanges.filter((e) => !e.told) : lastExchanges(options.remember === -1 ? MAX_EXCHANGES : within(options.remember, 0, MAX_EXCHANGES, RECAP_EXCHANGES));
    const title = session
      ? 'Meanwhile, the player also asked these, answered beside this session:'
      : 'What was asked and answered before (the start of each answer), for memory:';
    const asked = prompt(question, recapLines(news, title), web);
    return askClaude(asked, { session, aside, model, effort, web, addons: !off.includes('addons'), wowDir }).then((reply) => {
      if (!reply.error) reply.detail = detailOf(reply, asked, question.read, !session);
      if (!reply.error && !aside) news.forEach((e) => { e.told = true; });
      return reply;
    });
  };
  const resumed = aside ? null : state.session;
  let reply = await run(resumed);
  if (reply.error && resumed && /no conversation found/i.test(reply.error)) {
    leaveSession(`the session could not be resumed (${reply.error}): renewed, with a recap`);
    reply = await run(null);
  }

  const seconds = (Date.now() - begun) / 1000;
  if (reply.messages) {
    state.spent = [...state.spent, ...reply.messages].filter(({ at: when }) => when / 1000 > now() - WEEK_S);
    for (const { id, at: when, model: asked, usage } of reply.messages) ledger.note(id, when, asked, usage);
  }
  const plan = reply.plan && !off.includes('planShare') ? await withShare(reply.plan) : reply.plan;
  // the window only takes an answer marked with its question (answerMark)
  let text;
  if (reply.error) {
    log(`no answer: ${reply.error}`);
    text = `${answerMark(at, { plan, language: claudeLanguage() })}\n\n${failureText(reply.error, shownIn(question, wowDir))}`;
  } else {
    if (!aside && era === generation) {
      state.session = reply.session;
      state.context = reply.context;
      state.usedAt = now();
      state.model = model;
      state.effort = effort;
      state.setup = SETUP;
      state.chat = chat;
      state.game = wowDir;
      eraseLeft();
    } else if (!aside) {
      state.left.push(reply.session); // a new one was asked meanwhile
    }
    state.usedModel = reply.model;
    state.asked += 1;
    state.answered += 1;
    if (era === generation) {
      const start = reply.text.replace(/```[\s\S]*?(```|$)/g, '').replace(/\s+/g, ' ').trim();
      state.exchanges.push({
        tab: question.tab, question: question.text, told: !aside,
        answer: start.length > RECAP_CHARS ? `${start.slice(0, RECAP_CHARS)}…` : start,
      });
      state.exchanges = state.exchanges.slice(-MAX_EXCHANGES);
    }
    const mark = answerMark(at, { session: String(state.session || '').slice(0, 8), questions: state.asked, seconds, model: reply.model, context: state.context, spent: reply.spent, detail: reply.detail, plan, language: claudeLanguage() });
    const { text: answer, dropped } = keepRelated(fenced(reply.text), question.text, state.exchanges.map((e) => e.question));
    if (dropped.length) log(`questions left out, about something else or already asked: ${dropped.join(' / ')}`);
    text = `${mark}\n\n${await finished(answer, question, off, wowDir)}`;
  }
  state.outbox.push({ at, time: now(), text, wowDir, ...channelOf(question) });
  state.outbox.sort((a, b) => a.at - b.at);
  const ready = options.soundReady !== false;
  const { delivered, error } = deliver(wowDir, question, text, ready);
  if (error) log(`not put in the game: ${error}`);
  const copied = copyOutbox(ready && !delivered); // the game sounds by itself
  if (!reply.error) {
    log(`answered in ${Math.round(seconds)} s${delivered ? ', in the game' : ''}${copied.error ? `, not copied: ${copied.error}` : ', copied'} (${reply.model || 'model unknown'}, question ${state.asked} of the session, ${reply.context} tokens held, ${reply.spent.total} spent, ${state.outbox.length} to paste)`);
  }
  writeState(state);
}

// Every question is answered as soon as it comes, however many at once; in
// turn when the player prefers so.
function pump() {
  while (queue.length) {
    if (active > 0 && queue[0].question.options?.parallel === false) return; // once the others are done
    const { question, at, wowDir } = queue.shift();
    active += 1;
    state.waiting = active + queue.length;
    writeState(state);
    answer(question, at, wowDir).catch((error) => log(`failed: ${error.message}`)).then(() => {
      active -= 1;
      state.waiting = active + queue.length;
      writeState(state);
      pump();
      handOver();
    });
  }
}
wake = pump;
pump();
