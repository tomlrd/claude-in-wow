// Writes the textures of claude-in-wow's Claude window: the spark logo,
// discs for rounded corners and line icons in the style of claude.ai's. Each
// is white with its shape in the alpha channel, so the addon tints it
// (SetVertexColor); "LogoClay" comes already coloured, for the minimap button
// and the AddOns list. Shapes are signed distance fields, 4 x 4 samples per
// pixel. The game does not smooth a texture shrunk more than about twice, so
// each texture is drawn at twice the size it is shown at.
// node claude-art.mjs <out folder> [preview.png]

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const out = process.argv[2];
if (!out) throw new Error('usage: node claude-art.mjs <out folder> [preview.png]');
const previewFile = process.argv[3];
const SAMPLES = 4;
const CLAY = [0xd9, 0x77, 0x57];

// ---------------------------------------------------------------- distances

const hypot = Math.hypot;
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

function segment(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const t = clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy || 1), 0, 1);
  return hypot(px - ax - dx * t, py - ay - dy * t);
}

// An arc of a circle from angle a0 to a1 (radians, y down, clockwise).
function arc(px, py, cx, cy, r, a0, a1) {
  let a = Math.atan2(py - cy, px - cx);
  const span = (a1 - a0 + 4 * Math.PI) % (2 * Math.PI) || 2 * Math.PI;
  const rel = (a - a0 + 4 * Math.PI) % (2 * Math.PI);
  if (rel <= span) return Math.abs(hypot(px - cx, py - cy) - r);
  const e0 = hypot(px - cx - r * Math.cos(a0), py - cy - r * Math.sin(a0));
  const e1 = hypot(px - cx - r * Math.cos(a1), py - cy - r * Math.sin(a1));
  return Math.min(e0, e1);
}

// The outline of a rounded box (centre, half size, corner radius, angle).
function roundedBox(px, py, cx, cy, hx, hy, r, angle = 0) {
  const c = Math.cos(-angle), s = Math.sin(-angle);
  let x = (px - cx) * c - (py - cy) * s, y = (px - cx) * s + (py - cy) * c;
  const qx = Math.abs(x) - hx + r, qy = Math.abs(y) - hy + r;
  const outside = hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
  return Math.abs(outside);
}

// A capsule narrower at a (radius ra) than at b (radius rb); signed.
function unevenCapsule(px, py, ax, ay, bx, by, ra, rb) {
  px -= ax; py -= ay; bx -= ax; by -= ay;
  const h = bx * bx + by * by;
  let qx = (px * by - py * bx) / h, qy = (px * bx + py * by) / h;
  qx = Math.abs(qx);
  const b = ra - rb, cx = Math.sqrt(h - b * b), cy = b;
  const k = cx * qy - cy * qx, m = cx * qx + cy * qy, n = qx * qx + qy * qy;
  if (k < 0) return Math.sqrt(h * n) - ra;
  if (k > cx) return Math.sqrt(h * (n + 1 - 2 * qy)) - rb;
  return m - ra;
}

// ---------------------------------------------------------------- shapes

// Line icons, drawn in a 24-unit box with 2-unit strokes, as claude.ai's.
const S = (ax, ay, bx, by) => (x, y) => segment(x, y, ax, ay, bx, by);
const A = (cx, cy, r, d0, d1) => (x, y) => arc(x, y, cx, cy, r, d0 * Math.PI / 180, d1 * Math.PI / 180);
const B = (x0, y0, x1, y1, r, angle = 0) => (x, y) =>
  roundedBox(x, y, (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2, r, angle);
const C = (cx, cy, r) => (x, y) => Math.abs(hypot(x - cx, y - cy) - r);
const P = (...pts) => pts.slice(1).map((p, i) => S(pts[i][0], pts[i][1], p[0], p[1]));

const ICONS = {
  Close: [S(6, 6, 18, 18), S(18, 6, 6, 18)],
  Plus: [S(12, 5, 12, 19), S(5, 12, 19, 12)],
  ArrowUp: [S(12, 19, 12, 5), S(6, 11, 12, 5), S(18, 11, 12, 5)],
  Camera: [
    S(4, 7, 8, 7), S(16, 7, 20, 7), ...P([8, 7], [9.8, 4], [14.2, 4], [16, 7]),
    A(4, 9, 2, 180, 270), A(20, 9, 2, 270, 360), A(4, 18, 2, 90, 180), A(20, 18, 2, 0, 90),
    S(2, 9, 2, 18), S(22, 9, 22, 18), S(4, 20, 20, 20), C(12, 13, 3.5),
  ],
  NewChat: [
    S(12, 3, 5, 3), A(5, 5, 2, 180, 270), S(3, 5, 3, 19), A(5, 19, 2, 90, 180),
    S(5, 21, 19, 21), A(19, 19, 2, 0, 90), S(21, 19, 21, 12),
    B(8.6, 6.8, 22.4, 10.8, 2, -Math.PI / 4),
  ],
  Copy: [
    B(8, 8, 22, 22, 2),
    ...P([4, 16], [4, 16]), A(4, 14, 2, 90, 180), S(2, 14, 2, 4), A(4, 4, 2, 180, 270), S(4, 2, 14, 2), A(14, 4, 2, 270, 360),
  ],
  Chevron: [...P([4, 8], [12, 16], [20, 8])],
  Check: [...P([20, 6], [9, 17], [4, 12])],
  Bag: [
    ...P([6, 2.5], [3, 6.5], [3, 20]), A(5, 20, 2, 90, 180), S(5, 22, 19, 22), A(19, 20, 2, 0, 90),
    ...P([21, 20], [21, 6.5], [18, 2.5], [6, 2.5]), S(3, 6.5, 21, 6.5), A(12, 10, 4, 0, 180),
  ],
  MapPin: [
    A(12, 10, 8, 180, 360), ...P([4, 10], [5.3, 14.2], [8.2, 18.2], [12, 21.6], [15.8, 18.2], [18.7, 14.2], [20, 10]),
    C(12, 10, 3),
  ],
  Clipboard: [B(8, 2, 16, 6, 1), ...P([16, 4], [18, 4]), A(18, 6, 2, 270, 360), S(20, 6, 20, 20), A(18, 20, 2, 0, 90),
    S(18, 22, 6, 22), A(6, 20, 2, 90, 180), S(4, 20, 4, 6), A(6, 6, 2, 180, 270), S(6, 4, 8, 4)],
  Gear: [C(12, 12, 3), C(12, 12, 6.5),
    ...[0, 45, 90, 135, 180, 225, 270, 315].map((deg) => {
      const a = deg * Math.PI / 180, cx = 12 + 8.8 * Math.cos(a), cy = 12 + 8.8 * Math.sin(a);
      return (x, y) => roundedBox(x, y, cx, cy, 1.1, 1.5, 0.6, a);
    })],
  Trash: [S(3, 6, 21, 6), S(19, 6, 19, 20), A(17, 20, 2, 0, 90), S(17, 22, 7, 22), A(7, 20, 2, 90, 180), S(5, 20, 5, 6),
    ...P([8, 6], [8, 4]), A(10, 4, 2, 180, 270), S(10, 2, 14, 2), A(14, 4, 2, 270, 360), S(16, 4, 16, 6)],
};

function iconCoverage(parts) {
  return (x, y) => {
    let d = Infinity;
    for (const part of parts) d = Math.min(d, part(x, y));
    return d <= 1; // half the stroke
  };
}

// The spark: rays of uneven length and width from the centre, rounded at the
// tips, in the manner of Claude's mark. Angles clockwise from the top.
const RAYS = [
  [2, 1.0, 0.13], [35, 0.83, 0.115], [68, 0.96, 0.125], [100, 0.8, 0.11], [131, 0.95, 0.13],
  [164, 0.84, 0.115], [196, 1.0, 0.13], [229, 0.8, 0.11], [261, 0.93, 0.125], [294, 0.86, 0.12], [327, 0.97, 0.13],
];

function sparkCoverage(x, y) {
  let d = Infinity;
  for (const [deg, length, tip] of RAYS) {
    const a = deg * Math.PI / 180;
    const bx = Math.sin(a) * (length - tip), by = -Math.cos(a) * (length - tip);
    d = Math.min(d, unevenCapsule(x, y, 0, 0, bx, by, 0.07, tip));
  }
  return d <= 0;
}

// ---------------------------------------------------------------- rasterising

// alpha[size * size] from inside(x, y) over [x0, x1] x [y0, y1].
function raster(size, inside, x0, y0, x1, y1) {
  const alpha = new Uint8Array(size * size);
  const sx = (x1 - x0) / size, sy = (y1 - y0) / size;
  for (let py = 0; py < size; py++) {
    for (let px = 0; px < size; px++) {
      let hits = 0;
      for (let j = 0; j < SAMPLES; j++) {
        for (let i = 0; i < SAMPLES; i++) {
          if (inside(x0 + (px + (i + 0.5) / SAMPLES) * sx, y0 + (py + (j + 0.5) / SAMPLES) * sy)) hits++;
        }
      }
      alpha[py * size + px] = Math.round(hits / (SAMPLES * SAMPLES) * 255);
    }
  }
  return alpha;
}

// A 32-bit TGA, rows from the bottom, straight alpha.
function writeTga(file, size, alpha, rgb = [255, 255, 255]) {
  const data = Buffer.alloc(18 + size * size * 4);
  data[2] = 2; // uncompressed true colour
  data.writeUInt16LE(size, 12);
  data.writeUInt16LE(size, 14);
  data[16] = 32;
  data[17] = 8; // 8 alpha bits, origin at the bottom left
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const o = 18 + ((size - 1 - y) * size + x) * 4;
      data[o] = rgb[2]; data[o + 1] = rgb[1]; data[o + 2] = rgb[0]; data[o + 3] = alpha[y * size + x];
    }
  }
  fs.writeFileSync(file, data);
}

const made = [];
function make(name, size, alpha, rgb) {
  writeTga(path.join(out, `${name}.tga`), size, alpha, rgb);
  made.push({ name, size, alpha, rgb });
}

fs.mkdirSync(out, { recursive: true });
const SPARK_BOX = 1.08; // a little room around the longest rays
for (const size of [32, 64, 128]) make(`Logo${size}`, size, raster(size, sparkCoverage, -SPARK_BOX, -SPARK_BOX, SPARK_BOX, SPARK_BOX));
make('LogoClay', 64, raster(64, sparkCoverage, -SPARK_BOX, -SPARK_BOX, SPARK_BOX, SPARK_BOX), CLAY);
for (const size of [32, 64]) make(`Circle${size}`, size, raster(size, (x, y) => hypot(x, y) <= 1, -1, -1, 1, 1));
for (const [name, parts] of Object.entries(ICONS)) make(name, 32, raster(32, iconCoverage(parts), 0, 0, 24, 24));

// ---------------------------------------------------------------- preview

// Every texture on Claude's dark background, at 4 times its size then at the
// size the game shows it (half), tinted as the window tints it.
function writePng(file, width, height, rgba) {
  const crcTable = new Int32Array(256).map((_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c;
  });
  const crc = (buf) => { let c = -1; for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ -1) >>> 0; };
  const chunk = (type, body) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(body.length);
    const tb = Buffer.concat([Buffer.from(type), body]);
    const c = Buffer.alloc(4); c.writeUInt32BE(crc(tb));
    return Buffer.concat([len, tb, c]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}

if (previewFile) {
  const ZOOM = 4, GAP = 12, BG = [0x26, 0x26, 0x24], FG = [0xfa, 0xf9, 0xf5];
  const width = made.reduce((w, t) => w + t.size * ZOOM + GAP, GAP);
  const height = GAP * 3 + 128 * ZOOM + 64;
  const img = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) { img[i * 4] = BG[0]; img[i * 4 + 1] = BG[1]; img[i * 4 + 2] = BG[2]; img[i * 4 + 3] = 255; }
  const put = (x, y, rgb, a) => {
    const o = (y * width + x) * 4;
    for (let c = 0; c < 3; c++) img[o + c] = Math.round(img[o + c] * (1 - a) + rgb[c] * a);
  };
  let left = GAP;
  for (const t of made) {
    const tint = t.rgb || (t.name.startsWith('Logo') ? CLAY : FG);
    for (let y = 0; y < t.size * ZOOM; y++) {
      for (let x = 0; x < t.size * ZOOM; x++) put(left + x, GAP + y, tint, t.alpha[Math.floor(y / ZOOM) * t.size + Math.floor(x / ZOOM)] / 255);
    }
    // shown size: half, a box filter of 2 x 2 texels
    const half = t.size / 2;
    for (let y = 0; y < half; y++) {
      for (let x = 0; x < half; x++) {
        const a = (t.alpha[2 * y * t.size + 2 * x] + t.alpha[2 * y * t.size + 2 * x + 1]
          + t.alpha[(2 * y + 1) * t.size + 2 * x] + t.alpha[(2 * y + 1) * t.size + 2 * x + 1]) / 4 / 255;
        put(left + x, GAP * 2 + 128 * ZOOM + y, tint, a);
      }
    }
    left += t.size * ZOOM + GAP;
  }
  writePng(previewFile, width, height, img);
}

console.log(made.map((t) => `${t.name} ${t.size}`).join(', '));
