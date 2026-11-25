// Writes TrueType fonts of rectangles, as the game reads them: for the photos
// (tools/photo-font.mjs) and for the answers put in the game (deliver.mjs).
// Mac and Windows names, post format 2 and a descender, as in ordinary fonts.

class Writer {
  constructor() { this.parts = []; }
  u8(v) { this.parts.push(Buffer.from([v & 255])); return this; }
  u16(v) { const b = Buffer.alloc(2); b.writeUInt16BE(v & 0xffff); this.parts.push(b); return this; }
  i16(v) { const b = Buffer.alloc(2); b.writeInt16BE(v); this.parts.push(b); return this; }
  u32(v) { const b = Buffer.alloc(4); b.writeUInt32BE(v >>> 0); this.parts.push(b); return this; }
  bytes(buf) { this.parts.push(Buffer.from(buf)); return this; }
  done() { return Buffer.concat(this.parts); }
}

function checksum(buf) {
  const padded = buf.length % 4 ? Buffer.concat([buf, Buffer.alloc(4 - (buf.length % 4))]) : buf;
  let sum = 0;
  for (let i = 0; i < padded.length; i += 4) sum = (sum + padded.readUInt32BE(i)) >>> 0;
  return sum;
}

// A font: family, em (units), typical (a size of a part, for the OS/2 table)
// and glyphs, by character: { code, advance, rects }, rects [x0, y0, x1, y1]
// in font units, y up from the baseline. Without an advance, .notdef's.
export function buildFont({ family, postscript, em, typical, advance: usual, glyphs: drawn, descent = 1 }) {
  const glyphs = [{ rects: [], advance: usual }, ...drawn.map((glyph) => ({ advance: usual, ...glyph }))];
  const numGlyphs = glyphs.length;
  const codes = drawn.map((glyph) => glyph.code);
  const widest = Math.max(...glyphs.map((glyph) => glyph.advance));

  // glyf and loca
  const glyf = [];
  const loca = [0];
  let glyfLength = 0, maxPoints = 0, maxContours = 0;
  const bounds = glyphs.map(({ rects }) => (rects.length
    ? [Math.min(...rects.map((r) => r[0])), Math.min(...rects.map((r) => r[1])),
      Math.max(...rects.map((r) => r[2])), Math.max(...rects.map((r) => r[3]))]
    : [0, 0, 0, 0]));
  glyphs.forEach(({ rects }, index) => {
    if (rects.length) {
      const w = new Writer();
      const [xMin, yMin, xMax, yMax] = bounds[index];
      w.i16(rects.length).i16(xMin).i16(yMin).i16(xMax).i16(yMax);
      // clockwise outlines: up the left side, along the top, down the right side
      const points = rects.flatMap(([x0, y0, x1, y1]) => [[x0, y0], [x0, y1], [x1, y1], [x1, y0]]);
      rects.forEach((_, i) => w.u16(i * 4 + 3));
      w.u16(0); // no instructions
      points.forEach(() => w.u8(0x01)); // on curve, 16-bit coordinates
      let last = 0;
      points.forEach(([x]) => { w.i16(x - last); last = x; });
      last = 0;
      points.forEach(([, y]) => { w.i16(y - last); last = y; });
      let body = w.done();
      if (body.length % 4) body = Buffer.concat([body, Buffer.alloc(4 - (body.length % 4))]);
      glyf.push(body);
      glyfLength += body.length;
      maxPoints = Math.max(maxPoints, points.length);
      maxContours = Math.max(maxContours, rects.length);
    }
    loca.push(glyfLength);
  });
  const longLoca = glyfLength > 0x1fffe; // short offsets are halves

  const head = new Writer()
    .u32(0x00010000).u32(0x00010000).u32(0).u32(0x5f0f3cf5)
    .u16(0x0003).u16(em)
    .u32(0).u32(0).u32(0).u32(0) // created, modified
    .i16(0).i16(0).i16(usual).i16(em)
    .u16(0).u16(3).i16(2).i16(longLoca ? 1 : 0).i16(0) // macStyle, lowest size, direction, loca, glyph format
    .done();

  const hhea = new Writer()
    .u32(0x00010000).i16(em).i16(-descent).i16(0).u16(widest)
    .i16(0).i16(0).i16(usual).i16(1).i16(0).i16(0)
    .i16(0).i16(0).i16(0).i16(0).i16(0).u16(numGlyphs)
    .done();

  const maxp = new Writer()
    .u32(0x00010000).u16(numGlyphs).u16(maxPoints).u16(maxContours).u16(0).u16(0)
    .u16(2).u16(0).u16(0).u16(0).u16(0).u16(0).u16(0).u16(0).u16(0)
    .done();

  const os2 = new Writer()
    .u16(3).i16(usual).u16(400).u16(5).u16(0)
    .i16(typical).i16(typical).i16(0).i16(0).i16(typical).i16(typical).i16(0).i16(typical)
    .i16(100).i16(typical).i16(0)
    .bytes(Buffer.alloc(10)) // panose
    .u32(0x3).u32(0).u32(0).u32(0) // Basic Latin, Latin-1 Supplement
    .bytes(Buffer.from('NONE', 'latin1'))
    .u16(0x0040).u16(codes[0]).u16(codes[codes.length - 1])
    .i16(em).i16(-descent).i16(0).u16(em).u16(descent)
    .u32(1).u32(0)
    .i16(typical).i16(em).u16(0).u16(0x20).u16(0)
    .done();

  const hmtx = new Writer();
  glyphs.forEach(({ advance }, index) => hmtx.u16(advance).i16(bounds[index][0]));

  // cmap: format 4, one segment per run of characters with consecutive glyphs
  const segments = [];
  codes.forEach((code, i) => {
    const s = segments[segments.length - 1];
    if (s && code === s.end + 1) s.end = code;
    else segments.push({ start: code, end: code, delta: (i + 1 - code) & 0xffff });
  });
  segments.push({ start: 0xffff, end: 0xffff, delta: 1 });
  const segX2 = segments.length * 2;
  const searchRange = 2 * 2 ** Math.floor(Math.log2(segments.length));
  const sub = new Writer()
    .u16(4).u16(16 + segments.length * 8).u16(0)
    .u16(segX2).u16(searchRange).u16(Math.log2(searchRange / 2)).u16(segX2 - searchRange);
  segments.forEach((s) => sub.u16(s.end));
  sub.u16(0);
  segments.forEach((s) => sub.u16(s.start));
  segments.forEach((s) => sub.u16(s.delta));
  segments.forEach(() => sub.u16(0));
  const cmap = new Writer().u16(0).u16(2)
    .u16(0).u16(3).u32(4 + 16)
    .u16(3).u16(1).u32(4 + 16)
    .bytes(sub.done()).done();

  // name: Mac Roman and Windows Unicode records
  const names = [[1, family], [2, 'Regular'], [3, `${family} 1.0`], [4, family], [5, 'Version 1.0'], [6, postscript]];
  const records = [
    ...names.map(([id, text]) => ({ platform: 1, encoding: 0, language: 0, id, data: Buffer.from(text, 'latin1') })),
    ...names.map(([id, text]) => ({ platform: 3, encoding: 1, language: 0x409, id, data: Buffer.from(text, 'utf16le').swap16() })),
  ];
  const name = new Writer().u16(0).u16(records.length).u16(6 + records.length * 12);
  let offset = 0;
  records.forEach((r) => { name.u16(r.platform).u16(r.encoding).u16(r.language).u16(r.id).u16(r.data.length).u16(offset); offset += r.data.length; });
  records.forEach((r) => name.bytes(r.data));

  // post: format 2 names the ASCII glyphs from the Mac standard order (space
  // is 3, then one by one to asciitilde, 97); the others .notdef.
  const post = new Writer().u32(0x00020000).u32(0).i16(-100).i16(50).u32(1).u32(0).u32(0).u32(0).u32(0);
  post.u16(numGlyphs);
  glyphs.forEach(({ code }) => post.u16(code && code < 0x7f ? code - 0x20 + 3 : 0));

  const locaTable = new Writer();
  loca.forEach((v) => (longLoca ? locaTable.u32(v) : locaTable.u16(v / 2)));

  const tables = {
    'OS/2': os2, cmap, glyf: Buffer.concat(glyf), head, hhea, hmtx: hmtx.done(), loca: locaTable.done(),
    maxp, name: name.done(), post: post.done(),
  };
  const tags = Object.keys(tables).sort();
  const entrySelector = Math.floor(Math.log2(tags.length));
  const dirSearch = 16 * 2 ** entrySelector;
  const directory = new Writer().u32(0x00010000).u16(tags.length).u16(dirSearch).u16(entrySelector).u16(tags.length * 16 - dirSearch);
  let position = 12 + tags.length * 16;
  const bodies = [];
  for (const tag of tags) {
    const body = tables[tag];
    directory.bytes(Buffer.from(tag.padEnd(4), 'latin1')).u32(checksum(body)).u32(position).u32(body.length);
    const padded = body.length % 4 ? Buffer.concat([body, Buffer.alloc(4 - (body.length % 4))]) : body;
    bodies.push(padded);
    position += padded.length;
  }
  const font = Buffer.concat([directory.done(), ...bodies]);
  const headAt = 12 + tags.length * 16 + bodies.slice(0, tags.indexOf('head')).reduce((n, b) => n + b.length, 0);
  font.writeUInt32BE((0xb1b0afba - checksum(font)) >>> 0, headAt + 8);
  return font;
}
