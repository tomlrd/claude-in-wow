// A new version: npm run new-version -- <the addon's> [<the plugin's>]
// Writes it where it is, and says what is missing: what is new, in each language of the
// addon (CHANGES, under "= <version>") and in CHANGELOG.md. Alone: says whether the one
// there is ready to be released.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const toc = path.join(root, 'addon/claude-in-wow.toc'), json = path.join(root, 'plugin/.claude-plugin/plugin.json');
const read = (file) => fs.readFileSync(file, 'utf8');
const of = { addon: () => /^## Version: (.+)$/m.exec(read(toc))[1].trim(), plugin: () => JSON.parse(read(json)).version };
const newer = (a, b) => { const [x, y] = [a, b].map((v) => v.split('.').map(Number)); const at = x.findIndex((n, i) => n !== y[i]); return at >= 0 && x[at] > y[at]; };

const [addon, plugin] = process.argv.slice(2);
for (const [name, version] of [['addon', addon], ['plugin', plugin]]) {
  if (!version || version === of[name]()) continue;
  if (!/^\d+\.\d+\.\d+$/.test(version) || !newer(version, of[name]())) {
    console.error(`${version} is not a version after the ${name}'s ${of[name]()}`);
    process.exit(1);
  }
}
if (addon) fs.writeFileSync(toc, read(toc).replace(/^## Version: .+$/m, `## Version: ${addon}`));
if (plugin) fs.writeFileSync(json, read(json).replace(/"version": "[^"]+"/, `"version": "${plugin}"`));

const version = of.addon();
const missing = fs.readdirSync(path.join(root, 'addon/Locales')).filter((name) => !read(path.join(root, 'addon/Locales', name)).includes(`"= ${version}"`)).map((name) => `addon/Locales/${name}: CHANGES has no "= ${version}"`);
if (!new RegExp(`^## ${version.replaceAll('.', '\\.')}\\b`, 'm').test(read(path.join(root, 'CHANGELOG.md')))) missing.push(`CHANGELOG.md: no "## ${version}"`);
console.log(`addon ${version}, plugin ${of.plugin()}`);
if (missing.length) {
  console.error(`Missing:\n- ${missing.join('\n- ')}`);
  process.exit(1);
}
console.log('Ready: npm test, commit, then the tag v' + version + '.');
