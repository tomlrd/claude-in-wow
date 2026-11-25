// Makes the empty sound files that tell the game an answer is ready (the
// addon's Inbox.lua, the plugin's deliver.mjs), in the addon's Inbox folder.
// The game only finds files that were there when it started. Those that are
// there are kept as they are.
// node inbox.mjs <folder of the claude-in-wow addon>

import fs from 'node:fs';
import path from 'node:path';
import { SIGNALS } from '../plugin/server/deliver.mjs';

const addon = process.argv[2];
if (!addon || !fs.existsSync(path.join(addon, 'claude-in-wow.toc'))) {
  throw new Error('usage: node inbox.mjs <folder of the claude-in-wow addon>');
}
let made = 0;
fs.mkdirSync(path.join(addon, 'Inbox'), { recursive: true });
const numbers = Array.from({ length: SIGNALS }, (_, i) => String(i + 1).padStart(3, '0'));
for (const name of ['empty', ...numbers, ...numbers.map((number) => `a${number}`)]) { // aNNN: a question received
  const file = path.join(addon, 'Inbox', `${name}.wav`);
  if (fs.existsSync(file)) continue;
  fs.writeFileSync(file, '');
  made += 1;
}
console.log(`${made} files made.`);
