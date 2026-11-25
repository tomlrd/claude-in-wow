// Photos: the claude-in-wow addon cannot write a file while the game runs
// (saved data reaches the disk only at a reload or logout), but the game saves
// screenshots at once. So for a photo (/claude photo) the
// addon covers the screen with its data drawn in its own font, switches
// screenshots to PNG for one shot, and takes one. This reads those PNGs back.
// A compact photo (the addon's option, on by default) deflates the data and
// blacks out only the band it is drawn on: the game shows below it.
//
// The picture: white glyphs on black, from the top-left corner.
// - Each glyph is one base64 character: a bar across its top, a gap, then
//   3 x 2 cells, a lit cell for a 1 bit, read left to right then top to
//   bottom, most significant bit first. No glyph is blank: the game gives a
//   blank glyph its own width, the bars show where each glyph starts.
// - Row 0 is the header: 72 bytes of text, "CIW1 id page pages perRow rows
//   length adler32 rowPitch encoding width height", padded with spaces;
//   encoding is "json" or "deflate" (raw DEFLATE of the JSON).
// - Rows 1 and down, rowPitch pixels apart: this page's part of the data,
//   perRow glyphs a row.
// A photo too big for one screen takes several pages, one screenshot each;
// the data is cut into pages after it is deflated.

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

export const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
export const GLYPH_COLUMNS = 3;
export const GLYPH_ROWS = 2;
// A glyph's shape in dots (a pixel at the size the addon draws, 8): the bar,
// the gap under it, a cell's side. It is 9 dots wide and 8 high.
export const DOTS = { bar: 1, gap: 1, cell: 3 };
export const GLYPH_DOTS = { width: DOTS.cell * GLYPH_COLUMNS, height: DOTS.bar + DOTS.gap + DOTS.cell * GLYPH_ROWS };
export const HEADER_BYTES = 72;
export const MAGIC = 'CIW1';

// The cells lit for a value 0..63: [column, row] pairs.
export function glyphCells(value) {
  const cells = [];
  for (let k = 0; k < GLYPH_COLUMNS * GLYPH_ROWS; k++) {
    if ((value >> (5 - k)) & 1) cells.push([k % GLYPH_COLUMNS, Math.floor(k / GLYPH_COLUMNS)]);
  }
  return cells;
}

// A glyph as rectangles in dots, [x0, y0, x1, y1] from its top-left corner:
// the bar, then the lit cells.
export function glyphRects(value) {
  const top = DOTS.bar + DOTS.gap;
  return [[0, 0, GLYPH_DOTS.width, DOTS.bar], ...glyphCells(value).map(([column, row]) =>
    [column * DOTS.cell, top + row * DOTS.cell, (column + 1) * DOTS.cell, top + (row + 1) * DOTS.cell])];
}

// ---------------------------------------------------------------- PNG

// A PNG file as { width, height, channels, pixels } (8 bits a channel, not
// interlaced: what the game writes).
export function decodePng(buffer) {
  if (buffer.length < 33 || buffer.readUInt32BE(0) !== 0x89504e47) throw new Error('not a PNG file');
  let pos = 8, header = null;
  const data = [];
  while (pos + 12 <= buffer.length) {
    const length = buffer.readUInt32BE(pos);
    const type = buffer.toString('latin1', pos + 4, pos + 8);
    const body = buffer.subarray(pos + 8, pos + 8 + length);
    if (type === 'IHDR') {
      header = { width: body.readUInt32BE(0), height: body.readUInt32BE(4), depth: body[8], color: body[9], interlace: body[12] };
    } else if (type === 'IDAT') data.push(body);
    else if (type === 'IEND') break;
    pos += 12 + length;
  }
  const channels = { 0: 1, 2: 3, 4: 2, 6: 4 }[header?.color];
  if (!header || header.depth !== 8 || header.interlace !== 0 || !channels) throw new Error('unsupported PNG');

  const { width, height } = header;
  const raw = zlib.inflateSync(Buffer.concat(data));
  const stride = width * channels;
  if (raw.length < height * (stride + 1)) throw new Error('PNG cut short');
  const pixels = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const row = y * stride;
    for (let x = 0; x < stride; x++) {
      const left = x >= channels ? pixels[row + x - channels] : 0;
      const up = y > 0 ? pixels[row - stride + x] : 0;
      const upLeft = y > 0 && x >= channels ? pixels[row - stride + x - channels] : 0;
      let value = line[x];
      if (filter === 1) value += left;
      else if (filter === 2) value += up;
      else if (filter === 3) value += (left + up) >> 1;
      else if (filter === 4) {
        const p = left + up - upLeft;
        const pa = Math.abs(p - left), pb = Math.abs(p - up), pc = Math.abs(p - upLeft);
        value += pa <= pb && pa <= pc ? left : pb <= pc ? up : upLeft;
      }
      pixels[row + x] = value & 255;
    }
  }
  return { width, height, channels, pixels };
}

// ---------------------------------------------------------------- reading a photo

// Lit or not, by brightness.
function litTest(image) {
  const { width, height, channels, pixels } = image;
  const colour = channels >= 3;
  return (x, y) => {
    x = Math.floor(x); y = Math.floor(y);
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    const i = (y * width + x) * channels;
    return colour ? pixels[i] + pixels[i + 1] + pixels[i + 2] > 384 : pixels[i] > 128;
  };
}

// Runs of lit and dark pixels along a row: [{ lit, start, length }].
function runs(lit, y, width) {
  const out = [];
  let x = 0;
  while (x < width) {
    const value = lit(x, y), start = x;
    while (x < width && lit(x, y) === value) x++;
    out.push({ lit: value, start, length: x - start });
  }
  return out;
}

const HEADER_GLYPHS = (HEADER_BYTES / 3) * 4;

// The header's row, if the picture starts with one: where its bars are, the
// glyphs' size and pitch. The game leaves a pixel between glyphs; were the
// bars to touch, the bar's height gives the size (a cell is 3 bars).
function findLayout(image, lit) {
  for (let top = 0; top < Math.min(image.height, 200); top++) {
    const bars = runs(lit, top, image.width).filter((r) => r.lit);
    if (!bars.length) continue;
    const x0 = bars[0].start;
    let bar = 0;
    while (bar < 8 && lit(x0 + 1, top + bar)) bar++;
    if (bar === 0 || bar >= 8) return null;
    const width = bars[0].length;
    if (bars.length >= HEADER_GLYPHS && bars.slice(0, HEADER_GLYPHS).every((b) => Math.abs(b.length - width) <= 1)) {
      const pitch = (bars[HEADER_GLYPHS - 1].start - x0) / (HEADER_GLYPHS - 1);
      return { x0, top, bar, cell: width / GLYPH_COLUMNS, pitch, lit };
    }
    if (bars[0].length >= HEADER_GLYPHS * GLYPH_DOTS.width * bar - 2) { // one long bar
      const cell = (DOTS.cell / DOTS.bar) * bar;
      return { x0, top, bar, cell, pitch: cell * GLYPH_COLUMNS, lit };
    }
    return null;
  }
  return null;
}

// Where the glyphs of the row whose bars are on line y start: from its bars,
// else evenly from the header's.
function glyphStarts(layout, y, count) {
  const { x0, cell, pitch, lit } = layout;
  const bars = runs(lit, y, Math.ceil(x0 + (count + 1) * pitch)).filter((r) => r.lit).slice(0, count);
  if (bars.length === count && bars.every((b) => Math.abs(b.length - cell * GLYPH_COLUMNS) <= 1)) return bars.map((b) => b.start);
  return Array.from({ length: count }, (_, g) => x0 + g * pitch);
}

// The values of `count` glyphs whose bars are on line y.
function readGlyphs(layout, y, count) {
  const { bar, cell, lit } = layout;
  return glyphStarts(layout, y, count).map((x) => {
    let value = 0;
    for (let k = 0; k < GLYPH_COLUMNS * GLYPH_ROWS; k++) {
      const cx = x + ((k % GLYPH_COLUMNS) + 0.5) * cell;
      const cy = y + ((DOTS.bar + DOTS.gap) / DOTS.bar) * bar + (Math.floor(k / GLYPH_COLUMNS) + 0.5) * cell; // below the bar and the gap
      value = (value << 1) | (lit(cx, cy) ? 1 : 0);
    }
    return value;
  });
}

// The line of the bars of the row expected on line y: there, or a pixel or
// two off. A bar is lit across its glyph's first cells with the gap dark
// under it; a row of cells is as lit on the line below. (Rows may touch:
// the line above a bar can be lit.)
function barLine(layout, y) {
  const { x0, bar, cell, pitch, lit } = layout;
  const isBar = (line) => [0, 1, 2, 3].every((g) => {
    for (let x = x0 + g * pitch + 1; x < x0 + g * pitch + cell * GLYPH_COLUMNS - 1; x++) {
      if (!lit(x, line) || lit(x, line + bar)) return false;
    }
    return true;
  });
  for (const dy of [0, -1, 1, -2, 2]) {
    if (isBar(y + dy)) return y + dy;
  }
  return y;
}

// Base64 values, 4 for 3 bytes.
function fromValues(values, length) {
  const bytes = Buffer.alloc(Math.floor((values.length * 3) / 4));
  for (let i = 0, j = 0; i + 3 < values.length; i += 4) {
    const n = (values[i] << 18) | (values[i + 1] << 12) | (values[i + 2] << 6) | values[i + 3];
    bytes[j++] = n >> 16; bytes[j++] = (n >> 8) & 255; bytes[j++] = n & 255;
  }
  return bytes.subarray(0, length);
}

export function adler32(bytes) {
  let a = 1, b = 0;
  for (const byte of bytes) { a = (a + byte) % 65521; b = (b + a) % 65521; }
  return b * 65536 + a;
}

// One page of a photo from a decoded picture: { id, page, pages, encoding,
// chunk }, or null when the picture is not a photo (or a damaged one).
export function readPage(image) {
  const layout = findLayout(image, litTest(image));
  if (!layout) return null;
  const headerText = fromValues(readGlyphs(layout, layout.top, HEADER_GLYPHS), HEADER_BYTES).toString('latin1').trim();
  const fields = headerText.split(/ +/);
  if (fields[0] !== MAGIC || fields.length < 10) return null;
  const [id, page, pages, perRow, rows, length, sum, rowPitch] = fields.slice(1, 9).map(Number);
  const encoding = fields[9];
  if (![id, page, pages, perRow, rows, length, sum, rowPitch].every(Number.isFinite) || perRow <= 0 || rowPitch <= 0) return null;
  if (encoding !== 'json' && encoding !== 'deflate') return null;

  const values = [];
  const needed = Math.ceil(length / 3) * 4;
  for (let row = 1; values.length < needed && row <= rows; row++) {
    const y = barLine(layout, layout.top + row * rowPitch);
    values.push(...readGlyphs(layout, y, Math.min(perRow, needed - values.length)));
  }
  const chunk = fromValues(values, length);
  if (chunk.length !== length || adler32(chunk) !== sum) return null;
  return { id, page, pages, encoding, chunk };
}

// A whole photo's data from its pages' chunks, in order.
function photoData(chunks, encoding) {
  const bytes = Buffer.concat(chunks);
  return JSON.parse((encoding === 'deflate' ? zlib.inflateRawSync(bytes) : bytes).toString('utf8'));
}

// ---------------------------------------------------------------- the newest photo

const MAX_AGE_MS = 7 * 24 * 3600e3;
const pageCache = new Map(); // file -> { mtimeMs, size, page }

function pageOf(file, stat) {
  const cached = pageCache.get(file);
  if (cached && cached.mtimeMs === stat.mtimeMs && cached.size === stat.size) return cached.page;
  let page = null;
  try { page = readPage(decodePng(fs.readFileSync(file))); } catch { page = null; }
  pageCache.set(file, { mtimeMs: stat.mtimeMs, size: stat.size, page });
  return page;
}

// True for a screenshot known to be a photo (to leave out of the player's own).
export function isPhotoFile(file) {
  return Boolean(pageCache.get(file)?.page);
}

function remove(file) {
  try { fs.unlinkSync(file); pageCache.delete(file); } catch { /* still being written, or gone */ }
}

// Every photo in the Screenshots folder, its pages gathered: { photo (null
// while a page is missing, or when unreadable), files, mtimeMs, complete }.
function photosIn(screenshotsDir) {
  let names;
  try { names = fs.readdirSync(screenshotsDir); } catch { return []; }
  const now = Date.now();
  const groups = new Map(); // id -> { pages: Map(page -> file), count, mtimeMs }
  for (const name of names) {
    if (!/\.png$/i.test(name)) continue;
    const file = path.join(screenshotsDir, name);
    let stat;
    try { stat = fs.statSync(file); } catch { continue; }
    if (now - stat.mtimeMs > MAX_AGE_MS) continue;
    const page = pageOf(file, stat);
    if (!page) continue;
    const group = groups.get(page.id) || { pages: new Map(), count: page.pages, encoding: page.encoding, mtimeMs: 0, chunks: new Map() };
    group.pages.set(page.page, file);
    group.chunks.set(page.page, page.chunk);
    group.mtimeMs = Math.max(group.mtimeMs, stat.mtimeMs);
    groups.set(page.id, group);
  }

  return [...groups.values()].map((group) => {
    const files = [...group.pages.values()];
    const complete = group.pages.size === group.count;
    let photo = null;
    if (complete) {
      try {
        const chunks = [];
        for (let p = 1; p <= group.count; p++) chunks.push(group.chunks.get(p));
        photo = photoData(chunks, group.encoding);
      } catch { photo = null; }
    }
    const valid = photo && typeof photo.key === 'string' && typeof photo.savedAt === 'number';
    return { photo: valid ? photo : null, files, mtimeMs: group.mtimeMs, complete };
  });
}

// A question just sent may not be answered yet: its photo stays a while.
const KEEP_QUESTION_MS = 15 * 60e3;

function keepForQuestion(photo, now) {
  return Boolean(photo && isQuestion(photo.question) && now - photo.savedAt * 1000 < KEEP_QUESTION_MS);
}

// The newest whole photo in the Screenshots folder, newer than the snapshot
// time snapshotAt(key) gives: { key, savedAt, character, errors, question,
// files }. Photos it replaces are deleted: they are the addon's, not the
// player's (a question's photo stays a while, its answer may be due).
export function newestPhoto(screenshotsDir, snapshotAt) {
  const now = Date.now();
  // Whole photos still newer than their character's snapshot; the others
  // go, but for pages of one still being taken (the next page comes a
  // second later).
  const photos = [];
  for (const { photo, files, mtimeMs, complete } of photosIn(screenshotsDir)) {
    if (!complete && now - mtimeMs < 60e3) continue;
    if (photo && photo.savedAt > (snapshotAt(photo.key) || 0)) photos.push({ ...photo, files });
    else if (!keepForQuestion(photo, now)) files.forEach(remove);
  }

  // the newest; older ones are replaced
  photos.sort((a, b) => b.savedAt - a.savedAt);
  photos.slice(1).forEach((photo) => { if (!keepForQuestion(photo, now)) photo.files.forEach(remove); });
  return photos[0] || null;
}

// A question sent from the game's Claude window is
// { id, kind: "free"|"bags", text, at (unix seconds) }, with what was read in the
// game for it in question.read.
function isQuestion(question) {
  return Boolean(question) && typeof question.text === 'string' && question.text !== '';
}

// The questions sent after a time (unix seconds), the first sent first:
// [{ question, at, photo }]. Reads only: deletes nothing.
export function questionsAfter(screenshotsDir, after) {
  const found = [];
  for (const { photo } of photosIn(screenshotsDir)) {
    if (!photo || !isQuestion(photo.question)) continue;
    const at = Number(photo.question.at) || photo.savedAt;
    if (at > after) found.push({ question: photo.question, at, photo });
  }
  return found.sort((a, b) => a.at - b.at || a.photo.savedAt - b.photo.savedAt);
}

// The newest photo carrying a question sent after a time (of those takes(question)
// says to take), or null.
export function newestQuestion(screenshotsDir, after, takes = () => true) {
  return questionsAfter(screenshotsDir, after).filter(({ question }) => takes(question)).pop()?.photo || null;
}

// What the newest photo says of the places set apart in the game for what is said outside
// it ({ at, list: [{ signal, slot }] }), or null. Reads only.
export function newestSpare(screenshotsDir) {
  return photosIn(screenshotsDir).map(({ photo }) => photo?.spare).filter((spare) => Number.isFinite(spare?.at)).sort((a, b) => b.at - a.at)[0] || null;
}

// The saved data with the photo's character in place of the snapshot's (and
// the question it carries), and its Lua errors first.
export function withPhoto(db, photo) {
  const characters = { ...(db.characters || {}) };
  const old = characters[photo.key] || {};
  characters[photo.key] = {
    ...old, ...photo.character, savedAt: photo.savedAt, fromPhoto: true, reloadSavedAt: old.savedAt,
    question: isQuestion(photo.question) && photo.question.kind !== 'update' ? photo.question : undefined,
  };
  const id = (e) => `${e.character}|${e.message}`;
  const fresh = Array.isArray(photo.errors) ? photo.errors : [];
  const seen = new Set(fresh.map(id));
  const errors = [...fresh, ...(db.errors || []).filter((e) => !seen.has(id(e)))];
  return { ...db, characters, errors, warbandBank: photo.warbandBank || db.warbandBank };
}
