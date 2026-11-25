// Every test, one after the other: npm test
// LUA: the Lua to use ("lua5.2", or a program and its first arguments), when it is not found by itself.

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(here);
const addon = path.join(root, 'addon');
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-in-wow-tests-'));
const run = (program, args, options = {}) => spawnSync(program, args, { encoding: 'utf8', cwd: here, timeout: 15 * 60e3, ...options });

try { // the .env, for what is not set already
  for (const [, name, value] of fs.readFileSync(path.join(root, '.env'), 'utf8').matchAll(/^([A-Z_]+)=(.+?)\s*$/gm)) process.env[name] ??= value;
} catch { /* none */ }

const lua = (process.env.LUA ? [process.env.LUA.split(' ')] : [['lua5.2'], ['lua'], ['lua5.1'], ['luajit']])
  .find(([program, ...first]) => !run(program, [...first, '-e', 'print(1)']).error);
if (!lua) {
  console.error('No Lua found: install Lua 5.2, or set LUA to the one to use.');
  process.exit(1);
}

let failed = 0;
function test(name, program, args, options) {
  const { status, stdout, stderr, error } = run(program, args, options);
  const lines = String(stdout || '').trim().split(/\r?\n/);
  const last = lines.filter((line) => /passed/.test(line)).pop() || '';
  const good = !error && status === 0 && /\b0 failed/.test(last);
  if (!good) failed += 1;
  console.log(`${good ? 'ok  ' : 'FAIL'}  ${name}: ${last || error?.message || `exit ${status}`}`);
  if (!good) console.log([...lines.filter((line) => /^FAIL/.test(line)), String(stderr || '').trim()].filter(Boolean).join('\n'));
}
const withLua = (name, file, args, env = {}) => test(name, lua[0], [...lua.slice(1), file, ...args], { env: { ...process.env, ...env } });

// the sound files the answers come through, not in the repository
run(process.execPath, [path.join(root, 'tools/inbox.mjs'), addon], { stdio: 'ignore' });
const saved = path.join(work, 'ciw_sv.lua');
withLua('texts', 'locales_test.lua', [addon]);
for (const version of ['live', 'classic', 'classic_titan', 'classic_anniversary', 'classic_era', 'forever']) {
  withLua(`version ${version}`, 'versions_test.lua', [addon, 'versions.lua', version]);
}
for (const language of ['enUS', 'deDE', 'esES', 'itIT']) {
  withLua(`language ${language}`, 'versions_test.lua', [addon, 'versions.lua', 'forever'], { CIW_LOCALE: language });
}
withLua('addon', 'addon_test.lua', [addon, saved]);
// right after the addon's: it reads its saved data and its photo
test('plugin', process.execPath, [path.join(here, 'server_test.mjs'), path.join(root, 'plugin'), 'ciw_sv.lua'], { cwd: work });
try { fs.rmSync(work, { recursive: true, force: true }); } catch { /* in use */ }
console.log(failed ? `${failed} failed` : 'all passed');
process.exit(failed ? 1 : 0);
