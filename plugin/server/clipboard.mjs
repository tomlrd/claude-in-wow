// The way back into the game: nothing enters a running game but a paste, so
// the answer goes into the system clipboard, and a short sound says it is
// there. The player then presses Ctrl+V in the game's Claude window, whose box
// waits for the answer. The player's clipboard is replaced.
// CIW_CLIPBOARD_FILE (tests): the text goes in that file instead,
// with no sound.

import fs from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';

// PowerShell reads the text as UTF-8 from its input (accents intact), puts it
// in the clipboard, then plays the system's notification sound to its end.
const WINDOWS = [
  '[Console]::InputEncoding = [Text.Encoding]::UTF8',
  '$text = [Console]::In.ReadToEnd()',
  'Set-Clipboard -Value $text',
  'if ($env:FC_SOUND -eq "1") { [System.Media.SystemSounds]::Asterisk.Play(); Start-Sleep -Milliseconds 700 }',
].join('; ');

// The first line of an answer in the clipboard: which question of the game's
// window it answers (the time it was sent, in unix seconds), and what the
// silent mode knows of it, for the window to show: the Claude session, how
// many questions it has answered, how long this one took (in seconds), the
// model that answered, what the session holds (in thousands of tokens), and
// the tokens the answer took with, of them, those read again from the cache,
// where they went (silent.mjs, detailOf), the language Claude speaks, and how much of the player's plan is
// used (planOf: window:percent:when it resets, and the game's part of it, in
// hundredths of a percent, when it is known).
// The window refuses the answer to another question, such as the previous
// one still in the clipboard.
export function answerMark(at, info = {}) {
  const parts = [`réponse ${Math.floor(at)}`];
  if (info.session) parts.push(`session=${info.session}`);
  if (info.questions) parts.push(`n=${info.questions}`);
  if (info.seconds !== undefined) parts.push(`s=${Math.round(info.seconds)}`);
  const model = shortModel(info.model);
  if (model) parts.push(`m=${model}`);
  if (info.context) parts.push(`c=${Math.max(1, Math.round(info.context / 1000))}`);
  if (info.spent?.total) parts.push(`t=${info.spent.total} r=${info.spent.cached || 0}`);
  if (info.detail) parts.push(`d=${info.detail.map((n) => Math.round(n)).join(',')}`);
  if (info.plan) parts.push(`p=${info.plan.map(({ window, percent, resets, own }) => `${window}:${percent}:${resets}${own === undefined ? '' : `:${own}`}`).join(',')}`);
  if (info.cost !== undefined) parts.push(`u=${Math.round(info.cost * 1e6)}`);
  if (info.language) parts.push(`l=${info.language}`);
  return `[claude-in-wow ${parts.join(' ')}]`;
}

// "opus-5.5" of "claude-opus-5-5" (with or without a date); null of anything else.
export function shortModel(model) {
  const parts = /^claude-([a-z]+)-(\d{1,2})(?:-(\d{1,2}))?(?:-|\[|$)/.exec(String(model || ''));
  return parts ? `${parts[1]}-${parts[2]}${parts[3] ? `.${parts[3]}` : ''}` : null;
}

// A soft sound: a question was received and Claude is at work on it (the
// ready one is the system's notification sound). Windows' own "question" sound
// is often empty: one of its sound files instead.
export function playReceived() {
  if (process.env.CIW_CLIPBOARD_FILE) return; // tests
  if (process.platform === 'win32') {
    const child = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command',
      '(New-Object System.Media.SoundPlayer (Join-Path $env:WINDIR "Media/Windows Navigation Start.wav")).PlaySync()'], { stdio: 'ignore', windowsHide: true });
    child.on('error', () => { /* no sound */ });
    child.unref();
  } else if (process.platform === 'darwin') {
    const child = spawn('afplay', ['/System/Library/Sounds/Pop.aiff'], { stdio: 'ignore' });
    child.on('error', () => { /* no sound */ });
    child.unref();
  }
}

// { copied: true } or { error }.
export function toClipboard(text, sound = true) {
  const testFile = process.env.CIW_CLIPBOARD_FILE;
  if (testFile) {
    fs.writeFileSync(testFile, text);
    return { copied: true };
  }
  let result;
  if (process.platform === 'win32') {
    result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', WINDOWS], {
      input: text, encoding: 'utf8', env: { ...process.env, FC_SOUND: sound ? '1' : '0' }, timeout: 15000, windowsHide: true,
    });
  } else if (process.platform === 'darwin') {
    result = spawnSync('pbcopy', [], { input: text, encoding: 'utf8', timeout: 15000 });
    if (!result.error && result.status === 0 && sound) spawnSync('afplay', ['/System/Library/Sounds/Glass.aiff'], { timeout: 5000 });
  } else {
    return { error: 'Copying to the clipboard is only done on Windows and macOS.' };
  }
  if (result.error || result.status !== 0) {
    return { error: `The clipboard could not be set: ${result.error?.message || (result.stderr || '').trim() || `exit ${result.status}`}` };
  }
  return { copied: true };
}
