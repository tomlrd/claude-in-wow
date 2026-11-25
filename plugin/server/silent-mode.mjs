// The silent mode seen from outside: starting, stopping and asking how it
// goes (the silent_mode tool). The program itself is silent.mjs. Its state
// and log sit in the player's own folder (home.mjs).

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { dataDir } from './home.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));

export function silentFiles() {
  const dir = dataDir();
  return { state: path.join(dir, 'claude-in-wow-silent.json'), log: path.join(dir, 'claude-in-wow-silent.log') };
}

export function readState() {
  try { return JSON.parse(fs.readFileSync(silentFiles().state, 'utf8')); } catch { return null; }
}

export function writeState(state) {
  fs.writeFileSync(silentFiles().state, JSON.stringify(state, null, 1));
}

function alive(pid) {
  if (!pid) return false;
  try { process.kill(pid, 0); return true; } catch (error) { return error.code === 'EPERM'; }
}

// The running silent mode's state, or null.
export function running() {
  const state = readState();
  return state && alive(state.pid) ? state : null;
}

// The last lines of its log.
function lastLog(lines = 6) {
  try {
    return fs.readFileSync(silentFiles().log, 'utf8').trim().split('\n').slice(-lines);
  } catch { return []; }
}

export function status() {
  const state = running();
  if (!state) return { running: false, log: lastLog(3) };
  return {
    running: true,
    since: new Date(state.started * 1000).toLocaleString(),
    folder: state.dir,
    answered: state.answered || 0,
    session: state.session || null,
    questionsInSession: state.asked || 0,
    sessionTokens: state.context || 0,
    model: state.usedModel || null,
    answersToPaste: (state.outbox || []).length,
    questionsWaiting: state.waiting || 0,
    log: lastLog(),
  };
}

// Starts it again if the player had it running and it is no longer (the computer
// started again, or it failed): each time a Claude session opens these tools.
export function resume() {
  const state = readState();
  if (state?.wanted && state.dir && !alive(state.pid)) start(state.dir);
}

// What starts it, and ends at once: a session closed with all the programs it started
// does not take it away.
const LAUNCH = "const child = require('node:child_process').spawn(process.execPath, process.argv.slice(1), { detached: true, stdio: 'ignore', windowsHide: true }); child.unref(); console.log(child.pid);";

// Starts it, detached and hidden, Claude working in dir (the folder whose
// CLAUDE.md and memory apply to the answers).
export function start(dir) {
  const already = running();
  if (already) return { ...status(), started: false, note: 'The silent mode was already running.' };
  if (!fs.existsSync(dir)) return { error: `No folder ${dir}.` };
  const { stdout } = spawnSync(process.execPath, ['-e', LAUNCH, path.join(here, 'silent.mjs'), '--dir', dir], {
    encoding: 'utf8', windowsHide: true, env: process.env,
  });
  const pid = Number(stdout);
  return pid ? { started: true, pid, folder: dir } : { error: 'The silent mode could not be started.' };
}

export function stop() {
  const state = running();
  const last = readState();
  if (!state) {
    if (last?.wanted) writeState({ ...last, wanted: false });
    return { stopped: false, note: 'The silent mode was not running.' };
  }
  try { process.kill(state.pid); } catch { /* gone meanwhile */ }
  writeState({ ...last, wanted: false }); // not to be started again
  return { stopped: true, answered: state.answered || 0 };
}
