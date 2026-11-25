// Reads a WoW SavedVariables file: Lua assignments of tables, strings,
// numbers and booleans, as the game writes them.
//
// parseSavedVariables(buffer) -> { GlobalName: value, ... }
// A table whose keys are exactly 1..n becomes an array, any other an object;
// an empty table becomes an empty array (Object.entries reads it as empty too).

export function parseSavedVariables(buffer) {
  // One character per byte, so that "\ddd" escapes work on bytes; strings are
  // turned back into UTF-8 once read.
  const src = Buffer.isBuffer(buffer) ? buffer.toString('latin1') : String(buffer);
  let pos = 0;

  const fail = (message) => {
    const line = src.slice(0, pos).split('\n').length;
    throw new Error(`SavedVariables: ${message} (line ${line})`);
  };

  const skip = () => {
    for (;;) {
      while (pos < src.length && /\s/.test(src[pos])) pos++;
      if (src.startsWith('--', pos)) {
        pos += 2;
        const long = src.slice(pos).match(/^\[(=*)\[/);
        if (long) {
          const end = src.indexOf(`]${long[1]}]`, pos);
          pos = end < 0 ? src.length : end + long[1].length + 2;
        } else {
          while (pos < src.length && src[pos] !== '\n') pos++;
        }
        continue;
      }
      return;
    }
  };

  const utf8 = (latin1) => Buffer.from(latin1, 'latin1').toString('utf8');

  const ESCAPES = { n: '\n', t: '\t', r: '\r', a: '\x07', b: '\b', f: '\f', v: '\v', '\\': '\\', '"': '"', "'": "'", '\n': '\n' };

  const quoted = () => {
    const quote = src[pos++];
    let out = '';
    while (pos < src.length) {
      const c = src[pos++];
      if (c === quote) return utf8(out);
      if (c !== '\\') { out += c; continue; }
      const e = src[pos++];
      if (e in ESCAPES) out += ESCAPES[e];
      else if (e === '\r') { if (src[pos] === '\n') pos++; out += '\n'; }
      else if (/\d/.test(e)) {
        let digits = e;
        while (digits.length < 3 && /\d/.test(src[pos])) digits += src[pos++];
        out += String.fromCharCode(Number(digits) & 255);
      } else if (e === 'x') { out += String.fromCharCode(parseInt(src.substr(pos, 2), 16)); pos += 2; }
      else if (e === 'z') { while (/\s/.test(src[pos])) pos++; }
      else if (e === 'u') {
        const m = src.slice(pos).match(/^\{([0-9a-fA-F]+)\}/);
        if (!m) fail('bad \\u escape');
        out += Buffer.from(String.fromCodePoint(parseInt(m[1], 16)), 'utf8').toString('latin1');
        pos += m[0].length;
      } else out += e;
    }
    return fail('unfinished string');
  };

  const longString = () => {
    const m = src.slice(pos).match(/^\[(=*)\[\n?/);
    const close = `]${m[1]}]`;
    const end = src.indexOf(close, pos + m[0].length);
    if (end < 0) fail('unfinished long string');
    const text = src.slice(pos + m[0].length, end);
    pos = end + close.length;
    return utf8(text);
  };

  const NUMBER = /^-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)/;
  const NAME = /^[A-Za-z_][A-Za-z0-9_]*/;

  const value = () => {
    skip();
    const c = src[pos];
    if (c === '{') return table();
    if (c === '"' || c === "'") return quoted();
    if (c === '[' && /^\[=*\[/.test(src.slice(pos, pos + 10))) return longString();
    const number = src.slice(pos, pos + 64).match(NUMBER);
    if (number) {
      pos += number[0].length;
      const text = number[0];
      return /0[xX]/.test(text) ? (text[0] === '-' ? -1 : 1) * parseInt(text.replace(/^-/, ''), 16) : Number(text);
    }
    const name = src.slice(pos, pos + 64).match(/^-?[A-Za-z_][A-Za-z0-9_()]*/);
    if (name) {
      pos += name[0].length;
      switch (name[0]) {
        case 'true': return true;
        case 'false': return false;
        case 'nil': return null;
        case 'inf': case 'math.huge': return Infinity;
        case '-inf': return -Infinity;
        default:
          if (/nan/i.test(name[0])) return null;
          return fail(`unexpected ${name[0]}`);
      }
    }
    return fail(`unexpected ${JSON.stringify(c)}`);
  };

  const table = () => {
    pos++; // {
    const entries = new Map();
    let next = 1;
    for (;;) {
      skip();
      if (src[pos] === '}') { pos++; break; }
      let key;
      if (src[pos] === '[' && !/^\[=*\[/.test(src.slice(pos, pos + 10))) {
        pos++;
        key = value();
        skip();
        if (src[pos++] !== ']') fail('expected ]');
        skip();
        if (src[pos++] !== '=') fail('expected =');
        entries.set(key, value());
      } else {
        const name = src.slice(pos, pos + 128).match(NAME);
        const after = name && src.slice(pos + name[0].length).match(/^\s*=(?!=)/);
        if (name && after && !['true', 'false', 'nil'].includes(name[0])) {
          pos += name[0].length + after[0].length;
          entries.set(name[0], value());
        } else {
          entries.set(next++, value());
        }
      }
      skip();
      if (src[pos] === ',' || src[pos] === ';') pos++;
    }

    const n = entries.size;
    let isArray = true;
    for (let i = 1; i <= n; i++) if (!entries.has(i)) { isArray = false; break; }
    if (isArray) return Array.from({ length: n }, (_, i) => entries.get(i + 1)); // {} too: Lua can't tell

    const object = {};
    for (const [k, v] of entries) if (v !== null) object[String(k)] = v;
    return object;
  };

  const globals = {};
  for (;;) {
    skip();
    if (pos >= src.length) break;
    const name = src.slice(pos, pos + 256).match(NAME);
    if (!name) fail('expected a variable name');
    pos += name[0].length;
    skip();
    if (src[pos++] !== '=') fail('expected =');
    globals[name[0]] = value();
  }
  return globals;
}
