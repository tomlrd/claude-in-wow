// Sends the addon's zip to CurseForge (the release workflow does, once the project is there):
//   CF_API_TOKEN: the author's key (a secret of the repository), CF_PROJECT_ID: the
//   project's number (a variable of it). CF_SITE (tests): another server.
// node curseforge.mjs [--dry]: --dry says what would be sent, and sends nothing.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const site = /^http:\/\/127\.0\.0\.1:\d+$/.test(process.env.CF_SITE || '') ? process.env.CF_SITE : 'https://wow.curseforge.com';
const { CF_API_TOKEN: token, CF_PROJECT_ID: project } = process.env;
const dry = process.argv.includes('--dry');
const toc = fs.readFileSync(path.join(root, 'addon/claude-in-wow.toc'), 'utf8');
const version = /^## Version: (.+)$/m.exec(toc)[1].trim();
const file = path.join(root, 'dist', `claude-in-wow-${version}.zip`);

// 120105 is the game's 12.1.5
const games = /^## Interface: (.+)$/m.exec(toc)[1].split(',').map((one) => Number(one.trim())).map((n) => `${Math.floor(n / 10000)}.${Math.floor(n / 100) % 100}.${n % 100}`);
const part = new RegExp(`^## ${version.replaceAll('.', '\\.')}\\b.*\\n([\\s\\S]*?)(?=^## |$(?![\\s\\S]))`, 'm').exec(fs.readFileSync(path.join(root, 'CHANGELOG.md'), 'utf8'));
const changelog = (part?.[1] || '').trim();

if (!token || !/^\d+$/.test(project || '')) {
  console.log('CurseForge: no project yet (CF_API_TOKEN, CF_PROJECT_ID): nothing is sent.');
  process.exit(0);
}
const ask = async (url, options = {}) => {
  const answer = await fetch(`${site}${url}`, { ...options, headers: { 'X-Api-Token': token }, signal: AbortSignal.timeout(120e3) });
  if (!answer.ok) throw new Error(`CurseForge: ${answer.status} ${(await answer.text()).slice(0, 300)}`);
  return answer.json();
};
const known = new Map((await ask('/api/game/versions')).map(({ id, name }) => [name, id]));
const unknown = games.filter((name) => !known.has(name));
if (unknown.length) console.log(`CurseForge does not know ${unknown.join(', ')}: left out`);
const gameVersions = games.filter((name) => known.has(name)).map((name) => known.get(name));
if (!gameVersions.length) throw new Error('CurseForge knows none of the game\'s versions');
const metadata = { changelog, changelogType: 'markdown', displayName: `claude-in-wow ${version}`, gameVersions, releaseType: 'release' };
if (dry) {
  console.log(JSON.stringify(metadata, null, 1));
} else {
  const form = new FormData();
  form.set('metadata', JSON.stringify(metadata));
  form.set('file', new Blob([fs.readFileSync(file)], { type: 'application/zip' }), path.basename(file));
  const { id } = await ask(`/api/projects/${project}/upload-file`, { method: 'POST', body: form });
  console.log(`CurseForge: ${version} sent, file ${id}`);
}
