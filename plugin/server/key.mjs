// The player's own API key, for who has no Claude plan or prefers to pay by use: the
// silent mode's answers then use it (Anthropic's Console bills it), in place of the plan.
//   node key.mjs set      asks for it, hidden, and keeps it
//   node key.mjs remove   back to the plan
//   node key.mjs          which of the two is used
// The player types it in a terminal of their own: it never goes through Claude, nor the
// game, nor a command's words. It is kept by the system: on Windows, a file only this
// Windows account reads (DPAPI); on macOS, the keychain. Only claude itself is given it
// (silent.mjs). An ANTHROPIC_API_KEY already in the environment is never used: another
// program's, it would be billed unasked.
// CIW_KEY (tests): a file that holds it, in place of the one kept.

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { homeDir } from './home.mjs';

const ITEM = 'claude-in-wow';
const file = () => path.join(homeDir(), 'key.txt');
const mac = process.platform === 'darwin';

// PowerShell's, whatever terminal this is run from (its modules are not another version's).
function powershell(command, options) {
  const env = { ...Object.fromEntries(Object.entries(process.env).filter(([name]) => !/^PSModulePath$/i.test(name))), CIW_KEY_FILE: file() };
  return spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command], { encoding: 'utf8', env, windowsHide: true, ...options });
}

// Whether a key is kept, without reading it.
export function hasKey() {
  if (process.env.CIW_KEY) return fs.existsSync(process.env.CIW_KEY);
  if (process.platform === 'win32') return fs.existsSync(file());
  return mac && spawnSync('security', ['find-generic-password', '-s', ITEM], { stdio: 'ignore' }).status === 0;
}

// The key, or null; read again when it changes.
let kept = { mark: null, key: null };
export function readKey() {
  if (!hasKey()) return null;
  if (process.env.CIW_KEY) return fs.readFileSync(process.env.CIW_KEY, 'utf8').trim() || null;
  const mark = mac ? null : fs.statSync(file()).mtimeMs;
  if (mark && kept.mark === mark) return kept.key;
  const { stdout } = mac
    ? spawnSync('security', ['find-generic-password', '-s', ITEM, '-w'], { encoding: 'utf8' })
    : powershell('$s = Get-Content -LiteralPath $env:CIW_KEY_FILE | ConvertTo-SecureString; [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))');
  const key = String(stdout || '').trim() || null;
  if (key && mark) kept = { mark, key };
  return key;
}

// Asks for it in the terminal, and keeps it: true once done.
function setKey() {
  fs.mkdirSync(homeDir(), { recursive: true });
  if (mac) return spawnSync('security', ['add-generic-password', '-U', '-s', ITEM, '-a', 'api-key', '-w'], { stdio: 'inherit' }).status === 0;
  if (process.platform !== 'win32') return false;
  const { status } = powershell('$s = Read-Host -AsSecureString "Your API key (hidden)"; if ($s.Length -lt 20) { exit 2 }; ConvertFrom-SecureString $s | Set-Content -Encoding Ascii -LiteralPath $env:CIW_KEY_FILE', { stdio: 'inherit' });
  return status === 0;
}

function removeKey() {
  if (mac) spawnSync('security', ['delete-generic-password', '-s', ITEM], { stdio: 'ignore' });
  else fs.rmSync(file(), { force: true });
}

// What the player types in a terminal for it.
export const keyCommand = (action) => `node "${fileURLToPath(import.meta.url)}" ${action}`;

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const action = process.argv[2];
  if (action === 'set') console.log(setKey() ? 'Kept. The next answers use your API key, paid by use.' : 'Nothing kept.');
  else if (action === 'remove') { removeKey(); console.log('Removed. The next answers use your Claude plan.'); }
  else console.log(hasKey() ? 'The answers use your API key, paid by use.' : 'No API key: the answers use the account signed in to Claude Code.');
}
