// Writes the font the claude-in-wow addon draws its photos with: each
// base64 character is a bar over 3 x 2 square cells (see server/photo.mjs),
// 8 dots high and 9 wide, one em high, so that at a size of 8 pixels a dot
// is a pixel. The other printable characters of ASCII and Latin-1 are there,
// blank (server/ttf.mjs writes the file).
// The game only gets a font ready while the interface loads: the addon
// preloads this one (Photo.lua).
// node photo-font.mjs <out.ttf>

import fs from 'node:fs';
import path from 'node:path';
import { ALPHABET, GLYPH_DOTS, glyphRects } from '../plugin/server/photo.mjs';
import { buildFont } from '../plugin/server/ttf.mjs';

const out = process.argv[2];
if (!out) throw new Error('usage: node photo-font.mjs <out.ttf>');

const EM = 2048;
const DOT = EM / GLYPH_DOTS.height;

// Characters: printable ASCII, then printable Latin-1.
const chars = [
  ...Array.from({ length: 0x7f - 0x20 }, (_, i) => 0x20 + i),
  ...Array.from({ length: 0x100 - 0xa0 }, (_, i) => 0xa0 + i),
];
const font = buildFont({
  family: 'claude-in-wow Photo',
  postscript: 'ClaudeInWoWPhoto-Regular',
  em: EM,
  typical: DOT * 3,
  advance: DOT * GLYPH_DOTS.width, // the game leaves a pixel more between glyphs
  glyphs: chars.map((code) => {
    const value = ALPHABET.indexOf(String.fromCharCode(code));
    const rects = value < 0 ? [] : glyphRects(value).map(([x0, y0, x1, y1]) =>
      [x0 * DOT, (GLYPH_DOTS.height - y1) * DOT, x1 * DOT, (GLYPH_DOTS.height - y0) * DOT]);
    return { code, rects };
  }),
});

fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
fs.writeFileSync(out, font);
console.log(`${out}: ${chars.length + 1} glyphs, ${font.length} bytes`);
