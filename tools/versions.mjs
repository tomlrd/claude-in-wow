// The functions and events of each version of the game, from Blizzard's own
// documentation (the interface code published by Gethe/wow-ui-source), for
// tests/versions_test.lua.
// node versions.mjs <folder for the clones> <output.lua>

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const [root, output] = process.argv.slice(2);
const DOCS = 'Interface/AddOns/Blizzard_APIDocumentationGenerated';
const BRANCHES = ['live', 'classic', 'classic_titan', 'classic_anniversary', 'classic_era', 'forever'];
// used by everyone, not in the documentation
const UNDOCUMENTED = ['C_Timer.After', 'C_Timer.NewTicker', 'C_TradeSkillUI.IsTradeSkillReady', 'C_TradeSkillUI.GetAllRecipeIDs'];
const RETAIL_ONLY = new Set(['C_TradeSkillUI.IsTradeSkillReady', 'C_TradeSkillUI.GetAllRecipeIDs']);

const git = (args, cwd) => execFileSync('git', args, { cwd, stdio: 'ignore' });
fs.mkdirSync(root, { recursive: true });
const out = ['return {'];
for (const branch of BRANCHES) {
  const dir = path.join(root, branch);
  if (!fs.existsSync(dir)) {
    git(['clone', '--depth', '1', '--filter=blob:none', '--sparse', '-b', branch, 'https://github.com/Gethe/wow-ui-source.git', dir], root);
    git(['sparse-checkout', 'set', DOCS], dir);
  }
  const names = new Set();
  for (const name of fs.readdirSync(path.join(dir, DOCS)).filter((f) => f.endsWith('.lua'))) {
    const text = fs.readFileSync(path.join(dir, DOCS, name), 'utf8');
    const space = /Namespace = "([^"]+)"/.exec(text)?.[1];
    if (!space || !space.startsWith('C_')) continue;
    names.add(space);
    for (const m of text.matchAll(/Name = "([^"]+)",\r?\n\s*Type = "Function"/g)) names.add(`${space}.${m[1]}`);
  }
  const classic = branch.startsWith('classic');
  for (const name of UNDOCUMENTED) if (!classic || !RETAIL_ONLY.has(name)) { names.add(name); names.add(name.split('.')[0]); }
  out.push(`  ${branch} = { ${[...names].sort().map((n) => `["${n}"] = true`).join(', ')} },`);
}
out.push('}');
fs.writeFileSync(output, `${out.join('\n')}\n`);
console.log(`${BRANCHES.length} versions written to ${output}`);
