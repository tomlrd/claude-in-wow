// Makes the addon as players install it, in dist: npm run package
//   claude-in-wow-<version>.zip, the one for GitHub, CurseForge and the plugin's updates
//   (its .toc says X-Install: a copy a package made, which the updates may replace);
//   release.json: what the plugin reads to know what is out (plugin/server/updates.mjs).
// What is new comes from CHANGES in the languages (addon/Locales): the lines under the
// version's "= <version>".

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import zlib from 'node:zlib';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const dist = path.join(root, 'dist'), out = path.join(dist, 'claude-in-wow');
fs.rmSync(dist, { recursive: true, force: true });
fs.cpSync(path.join(root, 'addon'), out, { recursive: true, filter: (file) => path.basename(file) !== 'Inbox' });
for (const file of ['LICENSE', 'CHANGELOG.md']) fs.copyFileSync(path.join(root, file), path.join(out, file));
execFileSync(process.execPath, [path.join(root, 'tools/inbox.mjs'), out], { stdio: 'ignore' });
const tocFile = path.join(out, 'claude-in-wow.toc');
const toc = fs.readFileSync(tocFile, 'utf8');
const version = /^## Version: (.+)$/m.exec(toc)[1].trim();

const CRC = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc32 = (data) => { let c = 0xffffffff; for (const byte of data) c = CRC[(c ^ byte) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const everyFile = (dir, under = '') => fs.readdirSync(path.join(dir, under), { withFileTypes: true }).flatMap((entry) => {
  const name = under ? `${under}/${entry.name}` : entry.name;
  return entry.isDirectory() ? everyFile(dir, name) : [name];
}).sort();

// A zip of the folder, the same each time for the same files.
function zip(from) {
  const bodies = [], heads = [];
  let at = 0;
  for (const name of everyFile(from)) {
    const data = fs.readFileSync(path.join(from, name)), file = Buffer.from(`claude-in-wow/${name}`);
    const packed = zlib.deflateRawSync(data, { level: 9 });
    const common = Buffer.alloc(26);
    common.writeUInt16LE(20, 0);
    common.writeUInt16LE(0x0800, 2);
    common.writeUInt16LE(8, 4);
    common.writeUInt16LE(0x5a21, 8); // 1 January 2025
    common.writeUInt32LE(crc32(data), 10);
    common.writeUInt32LE(packed.length, 14);
    common.writeUInt32LE(data.length, 18);
    common.writeUInt16LE(file.length, 22);
    const local = Buffer.concat([Buffer.from([0x50, 0x4b, 3, 4]), common, file, packed]);
    const rest = Buffer.alloc(14);
    rest.writeUInt32LE(at, 10);
    heads.push(Buffer.concat([Buffer.from([0x50, 0x4b, 1, 2, 20, 0]), common, rest, file]));
    bodies.push(local);
    at += local.length;
  }
  const head = Buffer.concat(heads), end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(heads.length, 8);
  end.writeUInt16LE(heads.length, 10);
  end.writeUInt32LE(head.length, 12);
  end.writeUInt32LE(at, 16);
  return Buffer.concat([...bodies, head, end]);
}

fs.writeFileSync(tocFile, toc.replace(/^## Version: .*$/m, (line) => `${line}\n## X-Install: release`));
const ours = zip(out), file = `claude-in-wow-${version}.zip`;
fs.writeFileSync(path.join(dist, file), ours);

const notes = {};
for (const name of fs.readdirSync(path.join(root, 'addon/Locales'))) {
  const list = /^    CHANGES = \{([\s\S]*?)\n    \},$/m.exec(fs.readFileSync(path.join(root, 'addon/Locales', name), 'utf8'))?.[1];
  const lines = [...(list || '').matchAll(/^ *"((?:[^"\\]|\\.)*)",?$/gm)].map(([, line]) => line.replace(/\\(.)/g, '$1'));
  const from = lines.indexOf(`= ${version}`);
  if (from < 0) continue;
  const to = lines.findIndex((line, index) => index > from && line.startsWith('= '));
  notes[name.slice(0, 4)] = lines.slice(from + 1, to < 0 ? undefined : to);
}
const plugin = JSON.parse(fs.readFileSync(path.join(root, 'plugin/.claude-plugin/plugin.json'), 'utf8')).version;
const { needsAddon } = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
fs.writeFileSync(path.join(dist, 'release.json'), JSON.stringify({
  addon: { version, file, sha256: crypto.createHash('sha256').update(ours).digest('hex') },
  plugin: { version: plugin, needsAddon },
  notes,
  curseforge: 'https://www.curseforge.com/wow/addons/claude-in-wow',
}, null, 1));
console.log(version);
